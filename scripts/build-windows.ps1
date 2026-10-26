param([ValidateSet('win-arm64','win-x64')][string]$Runtime='win-arm64')
$ErrorActionPreference='Stop'
$Root=Split-Path $PSScriptRoot -Parent
Push-Location $Root
try {
    $MakeNSIS=$env:CHIRPOS_MAKENSIS
    if (-not $MakeNSIS) {
        $Command=Get-Command makensis -ErrorAction SilentlyContinue
        if ($Command) { $MakeNSIS=$Command.Source }
        else { $MakeNSIS=Join-Path ${env:ProgramFiles(x86)} 'NSIS\makensis.exe' }
    }
    if (-not (Test-Path -LiteralPath $MakeNSIS)) { throw 'Install NSIS 3 or set CHIRPOS_MAKENSIS to makensis.exe.' }
    $Packages=$env:CHIRPOS_PACKAGE_DIR
    if (-not $Packages) { $Packages=Join-Path $Root 'dist/releases' }
    New-Item -ItemType Directory -Force $Packages | Out-Null
    $Packages=(Resolve-Path -LiteralPath $Packages).Path
    & "$PSScriptRoot/test-windows-installer.ps1"
    dotnet run --project platforms/windows/ChirpOS.Tests -c Release -p:UseSharedCompilation=false
    if ($LASTEXITCODE -ne 0) { throw 'Core verification failed' }
    $Output=Join-Path $Root "dist/windows/$Runtime"
    dotnet publish platforms/windows/ChirpOS/ChirpOS.csproj -c Release -r $Runtime --self-contained false -p:UseSharedCompilation=false --disable-build-servers -o $Output
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
    Copy-Item LICENSE "$Output/LICENSE.txt"
    Copy-Item platforms/windows/Verify-Windows.cmd "$Output/Verify-Windows.cmd"
    Copy-Item platforms/windows/README.md "$Output/README.md"
    [xml]$Project=Get-Content platforms/windows/ChirpOS/ChirpOS.csproj
    $Version=$Project.Project.PropertyGroup.Version
    $Setup=Join-Path $Packages "ChirpOS-$Version-$Runtime-setup.exe"
    & $MakeNSIS /V2 "/DVERSION=$Version" "/DRID=$Runtime" "/DREPO_ROOT=$Root" "/DPAYLOAD_DIR=$Output" "/DOUTPUT_FILE=$Setup" "$Root/platforms/windows/installer/ChirpOS.nsi"
    if ($LASTEXITCODE -ne 0) { throw 'Windows installer build failed' }
    Compress-Archive -Path "$Output/ChirpOS.exe","$Output/LICENSE.txt","$Output/README.md","$Output/Verify-Windows.cmd" -DestinationPath "$Packages/ChirpOS-$Version-$Runtime-framework-dependent.zip" -CompressionLevel Optimal -Force
    if ($env:CHIRPOS_SHARE_DIR) {
        New-Item -ItemType Directory -Force $env:CHIRPOS_SHARE_DIR | Out-Null
        Copy-Item $Setup $env:CHIRPOS_SHARE_DIR
    }
    Write-Host "Installer: $Setup"
} finally { Pop-Location }
