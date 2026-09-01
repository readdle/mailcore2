# Builds the Windows prebuilt for the sources in this checkout and uploads it as a release
# asset. See AGENTS.md for the procedure and README.md for how the whole thing works.

Param(
    # Local copy of the dependency archive. Downloaded from the release when omitted.
    [string]$PrebuiltDependenciesArchive,
    [string]$WorkPath,
    # Rebuild and overwrite an archive that is already published. Same digest means the same
    # sources, so this replaces like with like - but it does discard the published bytes.
    [switch]$Force,
    [switch]$SkipUpload
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"
if (-Not $WorkPath) {
    $WorkPath = "$ProjectRoot\.build\prebuilt"
}

function Assert-GitHubCli {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI is required to publish. Install it once with: winget install --id GitHub.cli"
    }
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI is not authenticated. Run: gh auth login"
    }
}

# Adds one asset to the release. Never creates it: the release and the dependency archive are
# set up once by hand, and a script that quietly recreated a deleted release would hide the
# fact that every archive on it had gone with it.
function Publish-ReleaseAsset {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Clobber)
    Assert-MailcorePrebuiltRelease
    $uploadArgs = @($Script:MailcorePrebuiltReleaseTag, $Path, "--repo", $Script:MailcorePrebuiltRepo)
    if ($Clobber) { $uploadArgs += "--clobber" }
    & gh release upload @uploadArgs
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload $Path" }
}

# --- Preflight ------------------------------------------------------------------------------

if (-not $SkipUpload) {
    Assert-GitHubCli
    Assert-MailcorePrebuiltRelease
}

$Pins = Get-MailcorePins

# Throws when the digested paths are dirty: the archive must correspond to a committed state.
$Digest = Get-MailcoreSourceDigest -RepoRoot $ProjectRoot
$ArchiveName = Get-MailcorePrebuiltArchiveName -Digest $Digest
$GitRev = (& git -C $ProjectRoot rev-parse HEAD).Trim()

Write-Host ""
Write-Host "  source digest : $Digest" -ForegroundColor Cyan
Write-Host "  archive       : $ArchiveName" -ForegroundColor Cyan
Write-Host "  git revision  : $GitRev" -ForegroundColor Cyan
Write-Host ""

$AlreadyPublished = (-not $SkipUpload) -and (Test-MailcoreReleaseAsset -AssetName $ArchiveName)
if ($AlreadyPublished -and -not $Force) {
    Write-Host "These sources already have a published prebuilt ($ArchiveName) - nothing to do." -ForegroundColor Green
    Write-Host "Pass -Force to rebuild and overwrite it." -ForegroundColor DarkGray
    return
}
if ($AlreadyPublished) {
    Write-Host "$ArchiveName is already published; -Force given, it will be rebuilt and overwritten." -ForegroundColor Yellow
}

Push-Task -Name "Verify toolchain against windows\pins.json" -ScriptBlock {
    $toolsetRoot = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\$($Pins.toolchain.msvcToolset)"
    if (-not (Test-Path -LiteralPath $toolsetRoot)) {
        throw "MSVC toolset $($Pins.toolchain.msvcToolset) not found at $toolsetRoot. Install it, or update windows\pins.json (which changes the digest and therefore the archive name)."
    }
    $sdkRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\$($Pins.toolchain.windowsSdk)"
    if (-not (Test-Path -LiteralPath $sdkRoot)) {
        throw "Windows SDK $($Pins.toolchain.windowsSdk) not found at $sdkRoot. Install it, or update windows\pins.json."
    }
    Initialize-MailcoreSdkRoot
    Write-TaskLog "Toolchain matches the pins"
}

# --- Dependency archive ---------------------------------------------------------------------

$DependenciesPath = "$WorkPath\build-dependencies"
$InstallPath = "$WorkPath\mailcore2-install"
$StagePath = "$WorkPath\mailcore2-all"
$ArchivePath = "$WorkPath\$ArchiveName"

New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null

if (-not $PrebuiltDependenciesArchive) {
    $PrebuiltDependenciesArchive = Get-MailcoreDependenciesArchive -WorkPath $WorkPath -Pins $Pins
}

# --- Build ------------------------------------------------------------------------------------

# A published archive must contain only what this build produced. The install tree and the
# CMake output are reused across runs otherwise, so a second publish from a different revision
# on the same machine would ship leftovers from the first.
Push-Task -Name "Clean previous build output" -ScriptBlock {
    foreach ($stale in $InstallPath, $StagePath, "$ProjectRoot\.build\mailcore2", "$ProjectRoot\Externals") {
        if (Test-Path -LiteralPath $stale) {
            Write-TaskLog "Removing $stale"
            Remove-Item -LiteralPath $stale -Recurse -Force
        }
    }
}

Push-Task -Name "Build mailcore2" -ScriptBlock {
    & "$PSScriptRoot\Build-Mailcore2.ps1" `
        -DependenciesPath $DependenciesPath `
        -InstallPath $InstallPath `
        -PrebuiltDependenciesArchive $PrebuiltDependenciesArchive `
        -Install
}

Push-Task -Name "Stamp source digest" -ScriptBlock {
    New-Item -ItemType Directory -Path "$InstallPath\etc" -Force | Out-Null
    [IO.File]::WriteAllText("$InstallPath\etc\mailcore2-source-digest", "$Digest`n", (New-Object Text.UTF8Encoding $false))

    # The digest covers the pinned revisions, so the archive must really have been built from
    # them. Initialize-Dependencies re-points an existing checkout, and this is the proof.
    $expected = [ordered]@{
        "mailcore2-git-rev"  = $GitRev
        "ctemplate-git-rev"  = $Pins.dependencies.CTemplate.revision
        "libetpan-git-rev"   = $Pins.dependencies.LibEtPan.revision
        "tidy-html5-git-rev" = $Pins.dependencies.TidyHTML5.revision
    }
    foreach ($entry in $expected.GetEnumerator()) {
        $stampPath = "$InstallPath\etc\$($entry.Key)"
        if (-not (Test-Path -LiteralPath $stampPath)) { throw "The install tree has no $($entry.Key)" }
        $actual = (Get-Content -LiteralPath $stampPath -Raw).Trim()
        if ($actual -ne $entry.Value) {
            throw "$($entry.Key) is $actual but pins.json and the checkout say $($entry.Value)"
        }
    }
    Write-TaskLog "Install tree matches the checkout and the pins"
}

Push-Task -Name "Package $ArchiveName" -ScriptBlock {
    # The artifact must run without a separately installed VC redistributable.
    $vcRedistRoot = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC"
    if (-not (Test-Path -LiteralPath $vcRedistRoot)) {
        throw "No VC redistributable under $vcRedistRoot. Install the C++ workload of VS 2022 Build Tools."
    }
    $vcCrt = Get-ChildItem $vcRedistRoot -Filter msvcp140.dll -File -Recurse |
        Where-Object FullName -Match '\\x64\\Microsoft\.VC143\.CRT\\' |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if (-not $vcCrt) { throw "VC143 x64 redistributable DLLs not found under $vcRedistRoot" }
    Copy-Item "$vcCrt\*.dll" (Join-Path $InstallPath "bin") -Force

    # A clean staging directory: copying onto an existing one would nest it on the second run.
    if (Test-Path $StagePath) { Remove-Item $StagePath -Recurse -Force }
    if (Test-Path $ArchivePath) { Remove-Item $ArchivePath -Force }
    Copy-Item $InstallPath $StagePath -Recurse
    tar.exe -a -cf $ArchivePath -C $WorkPath mailcore2-all
    if ($LASTEXITCODE -ne 0) { throw "Packaging failed" }
}

Push-Task -Name "Verify $ArchiveName" -ScriptBlock {
    $checkDir = "$WorkPath\verify"
    if (Test-Path $checkDir) { Remove-Item $checkDir -Recurse -Force }
    New-Item -ItemType Directory -Path $checkDir -Force | Out-Null
    tar.exe -C $checkDir -xf $ArchivePath
    if (-not (Test-Path -LiteralPath "$checkDir\mailcore2-all")) {
        throw "The archive must contain exactly one root directory named mailcore2-all"
    }

    $unpackedDigest = Get-MailcoreArchiveDigest -UnpackedPath "$checkDir\mailcore2-all"
    if ($unpackedDigest -ne $Digest) {
        throw "The packaged archive carries digest '$unpackedDigest', expected '$Digest'"
    }

    # Direct non-system dependencies: a missing one only shows up at load time otherwise.
    $required = @(
        "mailcore2.dll", "CMailCore.dll",
        "libetpan.dll", "libctemplate.dll", "rdtidy.dll",
        "libcrypto-1_1-x64.dll", "libssl-1_1-x64.dll", "zlib.dll", "sasl2.dll",
        "dispatch.dll", "BlocksRuntime.dll",
        "msvcp140.dll", "vcruntime140.dll",
        # Still linked by the prebuilt ctemplate and libetpan.
        "msvcp120.dll", "msvcr120.dll"
    )
    $icuMajor = $Pins.versions.icu.Split(".")[0]
    $required += @("icuuc$icuMajor.dll", "icuin$icuMajor.dll", "icudt$icuMajor.dll")
    $missing = $required | Where-Object { -not (Test-Path -LiteralPath "$checkDir\mailcore2-all\bin\$_") }
    if ($missing) { throw "The archive is missing: $($missing -join ', ')" }

    $requiredHeaders = @("include\MailCore\MailCore.h", "include\CMailCore\CMailCore.h")
    $missingHeaders = $requiredHeaders | Where-Object { -not (Test-Path -LiteralPath "$checkDir\mailcore2-all\$_") }
    if ($missingHeaders) { throw "The archive is missing headers: $($missingHeaders -join ', ')" }

    Remove-Item $checkDir -Recurse -Force
    Write-TaskLog "Archive verified"
}

if ($SkipUpload) {
    Write-Host ""
    Write-Host "Built and verified (upload skipped): $ArchivePath" -ForegroundColor Green
    return
}

Push-Task -Name "Upload $ArchiveName" -ScriptBlock {
    Publish-ReleaseAsset -Path $ArchivePath -Clobber:$AlreadyPublished
}

Write-Host ""
Write-Host "Published $ArchiveName" -ForegroundColor Green
Write-Host "  sources : $Digest" -ForegroundColor Green
Write-Host "  revision: $GitRev" -ForegroundColor Green
Write-Host "  sha256  : $((Get-FileHash $ArchivePath -Algorithm SHA256).Hash)" -ForegroundColor Green
Write-Host ""
Write-Host "Nothing needs to be committed to mailcore2: the archive is named after these sources," -ForegroundColor Green
Write-Host "so any checkout of them finds it. Carry on with the commit, PR and tag as usual." -ForegroundColor Green
