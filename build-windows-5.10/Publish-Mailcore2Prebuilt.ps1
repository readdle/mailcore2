Param(
    [string]$WorkPath,
    # Rebuild and overwrite an archive that is already published. Same digest means the same
    # sources, so this replaces like with like.
    [switch]$Force,
    [switch]$SkipUpload
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Prebuilt-Common.ps1"

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

# Adds one asset to the release, which is set up once by hand and never created here.
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

# --- Dependency archive ---------------------------------------------------------------------

$DependenciesPath = "$WorkPath\build-dependencies"
$InstallPath = "$WorkPath\mailcore2-install"
$StagePath = "$WorkPath\mailcore2-all"
$ArchivePath = "$WorkPath\$ArchiveName"

New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null

# --- Build ------------------------------------------------------------------------------------

# A publish must package only what this build produced. The CMake binary directory matters as
# much as the install tree: src/CMakeLists.txt stages the public headers into it with file(COPY),
# which adds but never prunes, so a header from an earlier build on this machine would be
# packaged even though this revision does not declare it public.
Push-Task -Name "Clean previous build output" -ScriptBlock {
    foreach ($stale in $InstallPath, $StagePath, "$ProjectRoot\.build\mailcore2") {
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
        -Install
}

Push-Task -Name "Stamp source digest" -ScriptBlock {
    New-Item -ItemType Directory -Path "$InstallPath\etc" -Force | Out-Null
    [IO.File]::WriteAllText("$InstallPath\etc\mailcore2-source-digest", "$Digest`n", (New-Object Text.UTF8Encoding $false))

    $builtRev = (Get-Content -LiteralPath "$InstallPath\etc\mailcore2-git-rev" -Raw).Trim()
    if ($builtRev -ne $GitRev) {
        throw "The install tree reports revision $builtRev but the checkout is at $GitRev"
    }
    }

Push-Task -Name "Package $ArchiveName" -ScriptBlock {
    # The artifact must run without a separately installed VC redistributable.
    $vcRedistRoot = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC"
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
        "msvcp120.dll", "msvcr120.dll"
    )
    $missing = $required | Where-Object { -not (Test-Path -LiteralPath "$checkDir\mailcore2-all\bin\$_") }
    if ($missing) { throw "The archive is missing: $($missing -join ', ')" }

    # A header public-headers.cmake has always declared, so this stays true of older revisions.
    $requiredHeaders = @("include\MailCore\MailCore.h")
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
