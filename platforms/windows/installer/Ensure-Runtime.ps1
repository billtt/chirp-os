param(
    [Parameter(Mandatory=$true)][ValidateSet('win-x64','win-arm64')][string]$Runtime,
    [ValidateSet('Check','Install')][string]$Action='Check',
    [string]$Manifest=''
)
# Windows PowerShell 5.1 uses the Windows-provided .NET Framework. This helper
# must not require the modern .NET runtime it is responsible for installing.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
# Windows PowerShell 5.1 may evaluate parameter defaults before PSScriptRoot
# is populated. Resolve paths only after binding, independently of the cwd.
$RuntimeScriptDirectory=$PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RuntimeScriptDirectory)) {
    $RuntimeScriptDirectory=[IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}
if ([string]::IsNullOrWhiteSpace($Manifest)) {
    $Manifest=Join-Path $RuntimeScriptDirectory 'runtime.json'
}

function Test-CompatibleVersion([string]$Text, [version]$Minimum) {
    # Exclude previews and other major/minor versions, matching the app's
    # default patch roll-forward policy.
    return $Text -match '^\d+\.\d+\.\d+$' -and
        ([version]$Text).Major -eq $Minimum.Major -and
        ([version]$Text).Minor -eq $Minimum.Minor -and
        ([version]$Text) -ge $Minimum
}

function Test-DesktopRuntime([string]$Architecture, [version]$Minimum) {
    # Query both views explicitly: the installer itself is a 32-bit bootstrapper.
    foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)) {
        $base=$null; $key=$null
        try {
            $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view)
            $key=$base.OpenSubKey("SOFTWARE\dotnet\Setup\InstalledVersions\$Architecture")
            if ($null -eq $key) { continue }
            $location=[string]$key.GetValue('InstallLocation')
            if (-not $location) { continue }
            $dotnet=Join-Path $location 'dotnet.exe'
            if (-not (Test-Path -LiteralPath $dotnet -PathType Leaf)) { continue }
            $runtimes=@(& $dotnet --list-runtimes 2>$null)
            if ($LASTEXITCODE -ne 0) { continue }
            if (Test-RequiredFrameworks $runtimes $Minimum) { return $true }
        } finally {
            if ($null -ne $key) { $key.Dispose() }
            if ($null -ne $base) { $base.Dispose() }
        }
    }
    return $false
}

function Test-RequiredFrameworks([string[]]$Runtimes, [version]$Minimum) {
    $desktop=$false; $core=$false
    foreach ($line in $Runtimes) {
        if ($line -match '^(Microsoft\.WindowsDesktop\.App|Microsoft\.NETCore\.App) (\S+) \[') {
            $framework=$Matches[1]; $version=$Matches[2]
            if (Test-CompatibleVersion $version $Minimum) {
                if ($framework -eq 'Microsoft.WindowsDesktop.App') { $desktop=$true }
                if ($framework -eq 'Microsoft.NETCore.App') { $core=$true }
            }
        }
    }
    return $desktop -and $core
}

function Get-NativeArchitecture {
    if ($env:PROCESSOR_ARCHITEW6432) { return $env:PROCESSOR_ARCHITEW6432 }
    return $env:PROCESSOR_ARCHITECTURE
}

function Receive-RuntimePackage([uri]$Uri, [string]$Path) {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Uri -OutFile $Path -UseBasicParsing -TimeoutSec 300 -MaximumRedirection 0
}

function Install-RuntimePackage([string]$Path) {
    $process=Start-Process -FilePath $Path -ArgumentList '/install','/passive','/norestart' -Verb RunAs -Wait -PassThru
    return $process.ExitCode
}

function Invoke-RuntimeSetup {
    $download=$null
    try {
        $native=Get-NativeArchitecture
        if (($Runtime -eq 'win-arm64' -and $native -ne 'ARM64') -or $native -notin @('ARM64','AMD64')) {
            throw 'This package does not match this PC. Use ARM64 for ARM Windows or x64 for Intel/AMD Windows.'
        }
        $manifestData=Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
        $minimum=[version]$manifestData.minimumVersion
        $architecture=$Runtime.Substring(4)
        if (Test-DesktopRuntime $architecture $minimum) {
            Write-Output "Compatible .NET Desktop Runtime ($architecture) is already installed."
            return 0
        }
        if ($Action -eq 'Check') { return 10 }

        $package=$manifestData.files.$Runtime
        $uri=[uri]$package.url
        if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'builds.dotnet.microsoft.com' -or
            $uri.AbsolutePath -ne "/dotnet/WindowsDesktop/$($manifestData.version)/windowsdesktop-runtime-$($manifestData.version)-$Runtime.exe" -or
            $package.sha512 -notmatch '^[a-fA-F0-9]{128}$' -or
            -not (Test-CompatibleVersion $manifestData.version $minimum)) {
            throw 'Invalid runtime download manifest.'
        }
        $download=Join-Path $RuntimeScriptDirectory ('runtime-'+[guid]::NewGuid().ToString('N')+'.exe')
        Write-Output "Downloading Microsoft .NET Desktop Runtime $($manifestData.version) ($architecture)..."
        Receive-RuntimePackage $uri $download
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA512).Hash -ne $package.sha512) {
            throw 'Runtime download checksum mismatch. Please retry.'
        }
        $signature=Get-AuthenticodeSignature -LiteralPath $download
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(^|,\s*)O=Microsoft Corporation(,|$)') {
            throw 'The runtime installer does not have a valid Microsoft signature.'
        }
        Write-Output 'Installing the Microsoft runtime. Allow the Windows permission prompt to continue.'
        $code=Install-RuntimePackage $download
        if ($code -eq 3010 -or $code -eq 1641) { return 3010 }
        if ($code -ne 0) { throw "Microsoft runtime installation failed or was cancelled (code $code)." }
        if (-not (Test-DesktopRuntime $architecture $minimum)) { throw 'The required desktop runtime is still unavailable after installation.' }
        return 0
    } catch {
        Write-Output $_.Exception.Message
        return 1
    } finally {
        if ($download -and (Test-Path -LiteralPath $download)) { Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue }
    }
}

# Dot-sourcing exposes the pure version policy for the cross-platform tests.
if ($MyInvocation.InvocationName -ne '.') {
    $result=Invoke-RuntimeSetup
    # Keep diagnostics on stdout while returning only the final numeric result.
    $lines=@($result)
    if ($lines.Count -gt 1) { $lines[0..($lines.Count-2)] | Write-Output }
    exit [int]$lines[-1]
}
