$ErrorActionPreference='Stop'
$Root=Split-Path $PSScriptRoot -Parent
$Helper=Join-Path $Root 'platforms/windows/installer/Ensure-Runtime.ps1'
$ManifestPath=Join-Path $Root 'platforms/windows/installer/runtime.json'
foreach ($file in @($Helper,(Join-Path $Root 'scripts/build-windows.ps1'))) {
    $tokens=$null; $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
. $Helper -Runtime win-arm64 -Manifest $ManifestPath
$script:checks=0
function Check([bool]$Condition,[string]$Name) {
    if (-not $Condition) { throw "FAIL installer: $Name" }
    $script:checks++; Write-Host "PASS installer: $Name"
}
$defaultManifest=& {
    Push-Location ([IO.Path]::GetTempPath())
    try {
        . $Helper -Runtime win-arm64
        return $Manifest
    } finally { Pop-Location }
}
Check ($defaultManifest -eq $ManifestPath) 'default manifest resolves beside the script from another working directory'
Check ((Get-Content -LiteralPath $defaultManifest -Raw | ConvertFrom-Json).minimumVersion -eq '10.0.0') 'default manifest can actually be read'
# Exercise the real -File entry point as used by NSIS, without explicit Manifest.
# On Windows this checks the installed runtime; it never installs anything.
$powerShellExecutable=(Get-Process -Id $PID).Path
$native=$env:PROCESSOR_ARCHITEW6432
if (-not $native) { $native=$env:PROCESSOR_ARCHITECTURE }
$probeRuntime=if ($native -eq 'ARM64') { 'win-arm64' } else { 'win-x64' }
Push-Location ([IO.Path]::GetTempPath())
try {
    $probeOutput=@(& $powerShellExecutable -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Helper -Runtime $probeRuntime -Action Check 2>&1)
    $probeExit=$LASTEXITCODE
} finally { Pop-Location }
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    Check ($probeExit -in @(0,10)) ('Windows -File default entry point: '+($probeOutput -join ' '))
} else {
    Check ($probeExit -eq 1 -and ($probeOutput -join ' ') -like '*does not match this PC*') 'non-Windows -File entry point reaches platform check without path binding error'
}
[xml]$project=Get-Content -LiteralPath (Join-Path $Root 'platforms/windows/ChirpOS/ChirpOS.csproj')
$runtimeManifest=Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$minimumInProject=@($project.Project.PropertyGroup | ForEach-Object { $_.RuntimeFrameworkVersion } | Where-Object { $_ })[0]
Check ($runtimeManifest.minimumVersion -eq $minimumInProject) 'installer requirement matches application framework version'
Check (Test-CompatibleVersion '10.0.14' ([version]'10.0.0')) 'accept compatible patch'
foreach ($version in @('9.0.9','11.0.0','10.1.0','10.0.14-preview.1','not-a-version')) {
    Check (-not (Test-CompatibleVersion $version ([version]'10.0.0'))) "reject $version"
}
Check (-not (Test-CompatibleVersion '10.0.1' ([version]'10.0.2'))) 'respect minimum patch'
Check (Test-RequiredFrameworks @('Microsoft.NETCore.App 10.0.14 [C:\dotnet]','Microsoft.WindowsDesktop.App 10.0.14 [C:\dotnet]') ([version]'10.0.0')) 'require both desktop and core runtime'
Check (-not (Test-RequiredFrameworks @('Microsoft.NETCore.App 10.0.14 [C:\dotnet]') ([version]'10.0.0'))) 'plain .NET runtime is insufficient'
Check (-not (Test-RequiredFrameworks @('Microsoft.WindowsDesktop.App 10.0.14 [C:\dotnet]','Microsoft.NETCore.App 9.0.9 [C:\dotnet]') ([version]'10.0.0'))) 'incompatible core runtime is insufficient'

# Exercise the real orchestration with deterministic OS/network/installer seams.
# These tests never download or install a runtime or require administrator access.
function Get-NativeArchitecture { return $script:native }
function Test-DesktopRuntime([string]$Architecture,[version]$Minimum) {
    $script:checkedArch=$Architecture
    return $script:available
}
function Receive-RuntimePackage([uri]$Uri,[string]$Path) {
    $script:downloads++
    if ($script:offline) { throw 'Network unavailable' }
}
function Get-FileHash { return @{Hash=$script:hash} }
function Get-AuthenticodeSignature { return @{Status=$script:signature; SignerCertificate=@{Subject=$script:subject}} }
function Install-RuntimePackage([string]$Path) {
    $script:installs++
    $script:available=$script:availableAfterInstall
    return $script:exitCode
}
function Reset-Scenario {
    $script:native='ARM64'; $script:available=$false; $script:availableAfterInstall=$true
    $script:downloads=0; $script:installs=0; $script:offline=$false; $script:exitCode=0
    $script:signature='Valid'; $script:subject='CN=Microsoft Corporation, O=Microsoft Corporation, C=US'
    $script:hash=(Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json).files.'win-arm64'.sha512
}
function Result { $output=@(Invoke-RuntimeSetup); return [int]$output[-1] }
Reset-Scenario
$Action='Check'; $script:available=$true
Check ((Result) -eq 0 -and $script:downloads -eq 0) 'installed runtime skips download'
$script:available=$false
Check ((Result) -eq 10 -and $script:downloads -eq 0) 'check reports missing runtime without installing'
Check ($script:checkedArch -eq 'arm64') 'check the payload architecture'
$Runtime='win-x64'; $script:available=$true; $script:native='AMD64'
Check ((Result) -eq 0 -and $script:checkedArch -eq 'x64') 'reuse x64 runtime on Intel/AMD Windows'
$Runtime='win-arm64'; $script:available=$false
$script:native='AMD64'
Check ((Result) -eq 1 -and $script:downloads -eq 0) 'reject ARM package on x64 PC'
Reset-Scenario
$Action='Install'
Check ((Result) -eq 0 -and $script:downloads -eq 1 -and $script:installs -eq 1) 'missing runtime installs and is rechecked'
Reset-Scenario; $script:offline=$true
Check ((Result) -eq 1 -and $script:installs -eq 0) 'download failure never launches installer'
Reset-Scenario; $script:hash='bad'
Check ((Result) -eq 1 -and $script:installs -eq 0) 'checksum mismatch never launches installer'
Reset-Scenario; $script:signature='NotTrusted'
Check ((Result) -eq 1 -and $script:installs -eq 0) 'untrusted signature never launches installer'
Reset-Scenario; $script:subject='CN=Other, O=Other Company, C=US'
Check ((Result) -eq 1 -and $script:installs -eq 0) 'valid signature from wrong publisher is rejected'
foreach ($code in @(1602,1603,1223)) {
    Reset-Scenario; $script:exitCode=$code
    Check ((Result) -eq 1) "handle installer failure or cancellation $code"
}
foreach ($code in @(3010,1641)) {
    Reset-Scenario; $script:exitCode=$code
    Check ((Result) -eq 3010) "handle restart required $code"
}
Reset-Scenario; $script:availableAfterInstall=$false
Check ((Result) -eq 1) 'do not proceed when runtime is still missing'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('chirpos-runtime-test-'+[guid]::NewGuid()+'.json')
try {
    $data=Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $data.files.'win-arm64'.url='https://example.com/runtime.exe'
    $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $temp -Encoding UTF8
    Reset-Scenario; $Manifest=$temp
    Check ((Result) -eq 1 -and $script:downloads -eq 0) 'untrusted download source is rejected'
} finally { Remove-Item -LiteralPath $temp -Force; $Manifest=$ManifestPath }
Write-Host "$script:checks installer checks passed."
