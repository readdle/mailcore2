# Checks that this machine can build and publish the Windows prebuilt, against the versions in
# pins.json. Reports every prerequisite, then prints the install command for whatever is
# missing; -Install runs those commands instead of printing them.
#
# Nothing here is guesswork about your machine: each check looks at the exact path the build
# will look at, so a green line means the build will find it.

Param(
    [switch]$Install
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Common.ps1"

if (-not $IsWindows) {
    throw "This checks a Windows build machine. To ask whether a prebuilt is published - which needs no Windows - run Check-PrebuiltPublished.ps1 instead."
}

$Pins = Get-MailcorePins
$VsBuildTools = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"
$SwiftRoot = Join-Path $env:LOCALAPPDATA "Programs\Swift"

# MSVC toolset 14.39 is the VS 17.9 side-by-side component; the mapping is fixed by Microsoft.
$MsvcMinor = ($Pins.toolchain.msvcToolset -split "\.")[0..1] -join "."
$VsComponents = @(
    "Microsoft.VisualStudio.Workload.VCTools"
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
    "Microsoft.VisualStudio.Component.VC.$MsvcMinor.17.9.x86.x64"
    "Microsoft.VisualStudio.Component.VC.CMake.Project"
    "Microsoft.VisualStudio.Component.Windows11SDK." + ($Pins.toolchain.windowsSdk -split "\.")[2]
)

$Results = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param(
        [string]$Name,
        [string]$Detail,
        [bool]$Ok,
        [string]$Fix
    )
    $Results.Add([pscustomobject]@{ Name = $Name; Detail = $Detail; Ok = $Ok; Fix = $Fix })
}

function Test-Tool {
    param([string]$Name, [string]$Command, [string]$Fix)
    $found = Get-Command $Command -ErrorAction SilentlyContinue
    Add-Check -Name $Name -Detail $(if ($found) { $found.Source } else { "$Command not on PATH" }) -Ok ([bool]$found) -Fix $Fix
}

Write-Host ""
Write-Host "Checking against $(Get-MailcorePinsPath)" -ForegroundColor Cyan
Write-Host ""

Add-Check -Name "PowerShell 7+" -Detail $PSVersionTable.PSVersion.ToString() `
    -Ok ($PSVersionTable.PSVersion.Major -ge 7) `
    -Fix "winget install --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements"

Test-Tool -Name "git"        -Command "git"  -Fix "winget install --id Git.Git --accept-package-agreements --accept-source-agreements"
Test-Tool -Name "GitHub CLI" -Command "gh"   -Fix "winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements"
Test-Tool -Name "tar"        -Command "tar"  -Fix "Ships with Windows 10 1803 and later; update Windows."

# --- Visual Studio Build Tools ------------------------------------------------------------------

$vsInstallFix = "winget install --id Microsoft.VisualStudio.2022.BuildTools --override `"--quiet --wait --norestart $(($VsComponents | ForEach-Object { "--add $_" }) -join ' ')`""

Add-Check -Name "VS 2022 Build Tools" -Detail $VsBuildTools `
    -Ok (Test-Path -LiteralPath $VsBuildTools) -Fix $vsInstallFix

$toolsetRoot = "$VsBuildTools\VC\Tools\MSVC\$($Pins.toolchain.msvcToolset)"
Add-Check -Name "MSVC toolset $($Pins.toolchain.msvcToolset)" -Detail $toolsetRoot `
    -Ok (Test-Path -LiteralPath $toolsetRoot) -Fix $vsInstallFix

$sdkRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\$($Pins.toolchain.windowsSdk)"
Add-Check -Name "Windows SDK $($Pins.toolchain.windowsSdk)" -Detail $sdkRoot `
    -Ok (Test-Path -LiteralPath $sdkRoot) -Fix $vsInstallFix

foreach ($tool in @{ "CMake" = "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"; "Ninja" = "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe" }.GetEnumerator()) {
    $path = Join-Path $VsBuildTools $tool.Value
    Add-Check -Name "$($tool.Key) (from Build Tools)" -Detail $path -Ok (Test-Path -LiteralPath $path) -Fix $vsInstallFix
}

# --- Swift ----------------------------------------------------------------------------------

$swiftFix = "Install Swift $($Pins.toolchain.swift) for Windows from https://www.swift.org/install/windows/ (winget: Swift.Toolchain --version $($Pins.toolchain.swift))"

$toolchainsRoot = Join-Path $SwiftRoot "Toolchains"
$pinnedToolchain = $null
if (Test-Path -LiteralPath $toolchainsRoot) {
    $pinnedToolchain = Get-ChildItem -LiteralPath $toolchainsRoot -Directory |
        Where-Object { $_.Name -eq $Pins.toolchain.swift -or $_.Name -like "$($Pins.toolchain.swift)+*" } |
        Sort-Object Name | Select-Object -First 1
}
Add-Check -Name "Swift toolchain $($Pins.toolchain.swift)" `
    -Detail $(if ($pinnedToolchain) { $pinnedToolchain.FullName } else { "not found under $toolchainsRoot" }) `
    -Ok ([bool]$pinnedToolchain) -Fix $swiftFix

$swiftSdk = Join-Path $SwiftRoot "Platforms\$($Pins.toolchain.swift)\Windows.platform\Developer\SDKs\Windows.sdk"
Add-Check -Name "Swift Windows SDK" -Detail $swiftSdk -Ok (Test-Path -LiteralPath $swiftSdk) -Fix $swiftFix

# --- gh authentication ------------------------------------------------------------------------

$ghAuthenticated = $false
if (Get-Command gh -ErrorAction SilentlyContinue) {
    & gh auth status 2>&1 | Out-Null
    $ghAuthenticated = ($LASTEXITCODE -eq 0)
}
Add-Check -Name "gh authenticated" -Detail $(if ($ghAuthenticated) { "yes" } else { "no - publishing will refuse to run" }) `
    -Ok $ghAuthenticated -Fix "gh auth login"

# --- Report -------------------------------------------------------------------------------------

foreach ($result in $Results) {
    if ($result.Ok) {
        Write-Host ("  [ok]      {0,-32} {1}" -f $result.Name, $result.Detail) -ForegroundColor Green
    }
    else {
        Write-Host ("  [missing] {0,-32} {1}" -f $result.Name, $result.Detail) -ForegroundColor Red
    }
}
Write-Host ""

$missing = @($Results | Where-Object { -not $_.Ok })
if (-not $missing) {
    Write-Host "This machine can build and publish the Windows prebuilt." -ForegroundColor Green
    Write-Host "Next: .\windows\Publish-Mailcore2Prebuilt.ps1" -ForegroundColor DarkGray
    Write-Host ""
    return
}

# One fix can cover several checks (the Build Tools installer covers four).
$fixes = $missing | ForEach-Object { $_.Fix } | Select-Object -Unique

if (-not $Install) {
    Write-Host "Run these, then re-run this script:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($fix in $fixes) { Write-Host "    $fix" }
    Write-Host ""
    Write-Host "Or re-run with -Install to have them run for you." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

foreach ($fix in $fixes) {
    if ($fix -notlike "winget *" -and $fix -notlike "gh auth*") {
        Write-Host "Cannot automate, do this by hand: $fix" -ForegroundColor Yellow
        continue
    }
    Write-Host ""
    Write-Host "== $fix" -ForegroundColor Cyan
    & cmd.exe /d /c $fix
    if ($LASTEXITCODE -ne 0) {
        Write-Host "That command failed with exit code $LASTEXITCODE - run it by hand and check the package id." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Re-run this script to confirm what is now in place." -ForegroundColor Yellow
Write-Host ""
