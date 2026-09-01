# Shared ground for every script in this directory: which PowerShell helpers are in scope,
# where the prebuilt archives live, and how the C/C++ sources they were built from are
# identified.
#
# The archive name is derived from the content of the sources, not from a version number, so
# there is nothing to bump and nothing to forget: sources that were never built simply have no
# archive, and the build says so.

$Script:MailcorePrebuiltRepo = "readdle/mailcore2"
$Script:MailcorePrebuiltReleaseTag = "windows-prebuilt"
$Script:MailcorePrebuiltUrlBase = "https://github.com/$Script:MailcorePrebuiltRepo/releases/download/$Script:MailcorePrebuiltReleaseTag"

# The RD modules are internal. They supply Initialize-SDK and Invoke-BuildModuleTarget, which
# only the Swift build needs; everything else comes from Build-Helpers.ps1, dot-sourced
# afterwards so that its definitions shadow the RD ones. That order matters: the RD versions of
# Initialize-Toolchain and Invoke-VsDevCmd do not read pins.json, and the pinned toolchain has
# to be the one that actually runs, not just the one we claim to have used.
foreach ($module in "RDBuildCMake", "RDBuildMSVC", "RDDependency") {
    if (Get-Module -ListAvailable $module) { Import-Module $module }
}
. "$PSScriptRoot\Build-Helpers.ps1"

function Get-MailcorePinsPath {
    return (Join-Path $PSScriptRoot "pins.json")
}

function Get-MailcorePins {
    $path = Get-MailcorePinsPath
    if (-not (Test-Path -LiteralPath $path)) { throw "Build pins not found: $path" }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

# Everything that determines the content of the prebuilt binaries: the C/C++ sources (Swift is
# compiled from source at build time, so src/swift is excluded) plus the pins for the bundled
# dependencies and the toolchain. Deliberately NOT the build scripts - editing them would
# invalidate perfectly good binaries. The flip side is that a script change which alters what
# lands in the archive (adding a DLL to the install step, say) needs the archive re-published
# by hand; see AGENTS.md.
function Get-MailcoreDigestPathSpec {
    return @("src", "CMakeLists.txt", "windows/pins.json")
}

# A digest of git's own tree entries, not of file bytes: git already stores a hash per blob, so
# this is instant and, more importantly, identical on every platform - core.autocrlf cannot
# change it, unlike hashing working-tree content.
function Get-MailcoreSourceDigest {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        # Anything git resolves to a tree. Only HEAD can be checked for local edits, so only
        # HEAD is; other refs are read straight out of the object store.
        [string]$Ref = "HEAD"
    )

    $paths = Get-MailcoreDigestPathSpec

    if ($Ref -eq "HEAD") {
        # src/swift is outside the digest, so a dirty file there must not block the build either.
        $status = @(& git -C $RepoRoot status --porcelain -- @paths | Where-Object { $_ -notmatch " src/swift/" })
        if ($LASTEXITCODE -ne 0) { throw "Not a git checkout: $RepoRoot" }
        if ($status) {
            throw "Uncommitted changes under $($paths -join ', '): the digest describes HEAD, so it would not match what is built. Commit them, or build from source with -BuildMailcore2.`n$($status -join "`n")"
        }
    }

    $lines = & git -C $RepoRoot ls-tree -r $Ref -- @paths
    if ($LASTEXITCODE -ne 0) { throw "git ls-tree failed for $Ref in $RepoRoot" }
    $lines = $lines | Where-Object { $_ -notmatch "`tsrc/swift/" }
    if (-not $lines) { throw "No source entries found at $Ref in $RepoRoot - wrong directory?" }

    # Canonical listing: git's own order, LF endings, UTF-8 without BOM. Written to a file
    # rather than piped, because PowerShell re-encodes text between processes.
    $text = ($lines -join "`n") + "`n"
    $tempFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tempFile, $text, (New-Object Text.UTF8Encoding $false))
        $digest = & git -C $RepoRoot hash-object --no-filters $tempFile
        if ($LASTEXITCODE -ne 0) { throw "git hash-object failed" }
    }
    finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction Ignore
    }

    return $digest.Trim()
}

function Get-MailcorePrebuiltArchiveName {
    param([Parameter(Mandatory = $true)][string]$Digest)
    return "mailcore2-all-$($Digest.Substring(0, 12)).zip"
}

function Get-MailcorePrebuiltUrl {
    param([Parameter(Mandatory = $true)][string]$ArchiveName)
    return "$Script:MailcorePrebuiltUrlBase/$ArchiveName"
}

# The digest of the sources an unpacked archive was built from.
function Get-MailcoreArchiveDigest {
    param([Parameter(Mandatory = $true)][string]$UnpackedPath)
    $stamp = Join-Path $UnpackedPath "etc\mailcore2-source-digest"
    if (-not (Test-Path -LiteralPath $stamp)) { return $null }
    return (Get-Content -LiteralPath $stamp -Raw).Trim()
}

# --- The release ------------------------------------------------------------------------------

# The release is a permanent container for binaries, set up once by hand. The scripts only add
# archives to it.
$Script:MailcoreReleaseSetupHelp = @"
The $Script:MailcorePrebuiltReleaseTag release does not exist, or is not visible to this token.
It is created once, by hand:

  1. https://github.com/$Script:MailcorePrebuiltRepo/releases/new?tag=$Script:MailcorePrebuiltReleaseTag
     Tag $Script:MailcorePrebuiltReleaseTag, marked as a pre-release.
  2. Attach the dependency archive to it, under the name pins.json gives it.
"@

function Test-MailcorePrebuiltRelease {
    & gh release view $Script:MailcorePrebuiltReleaseTag --repo $Script:MailcorePrebuiltRepo --json tagName 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Assert-MailcorePrebuiltRelease {
    if (-not (Test-MailcorePrebuiltRelease)) { throw $Script:MailcoreReleaseSetupHelp }
}

# Names of every asset on the prebuilt release, or an empty array when there is no release.
# Needs gh on PATH and authenticated (GH_TOKEN is enough in CI).
function Get-MailcoreReleaseAssetNames {
    $assets = & gh release view $Script:MailcorePrebuiltReleaseTag --repo $Script:MailcorePrebuiltRepo --json assets --jq ".assets[].name" 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($assets)
}

function Test-MailcoreReleaseAsset {
    param([Parameter(Mandatory = $true)][string]$AssetName)
    return ((Get-MailcoreReleaseAssetNames) -contains $AssetName)
}

# --- The dependency archive -------------------------------------------------------------------

# The binary build inputs (ICU, libxml2, openssl, sasl, zlib) travel as one archive with a
# single top-level directory. Its layout is a contract between New-DependenciesArchive.ps1 and
# Build-Mailcore2.ps1, so it lives here, in one place, as paths relative to that directory.
function Get-MailcoreDependenciesLayout {
    param([Parameter(Mandatory = $true)]$Pins)
    return [ordered]@{
        Icu     = "icu-$($Pins.versions.icu)\usr"
        LibXml2 = "libxml2-$($Pins.versions.libxml2)\usr"
        OpenSsl = "openssl"
        Sasl    = "sasl"
        Zlib    = "zlib"
    }
}

# The individual files the build actually opens. Checked right after extraction so that a
# malformed archive fails with the missing path rather than with a CMake error 200 lines later.
function Get-MailcoreDependenciesRequiredFiles {
    param([Parameter(Mandatory = $true)]$Pins)
    $icuMajor = $Pins.versions.icu.Split(".")[0]
    return @(
        "icu-$($Pins.versions.icu)\usr\bin\icuuc$icuMajor.dll",
        "icu-$($Pins.versions.icu)\usr\bin\icuin$icuMajor.dll",
        "icu-$($Pins.versions.icu)\usr\bin\icudt$icuMajor.dll",
        "icu-$($Pins.versions.icu)\usr\lib\x64\icuuc$icuMajor.lib",
        "icu-$($Pins.versions.icu)\usr\lib\x64\icuin$icuMajor.lib",
        "icu-$($Pins.versions.icu)\usr\include\unicode\uversion.h",
        "libxml2-$($Pins.versions.libxml2)\usr\lib\x64\libxml2s.lib",
        # CMakeLists.txt appends /libxml2 to LIBXML_INCLUDE_DIR on Windows, so the headers stay
        # where libxml2's own install step puts them rather than being relaid.
        "libxml2-$($Pins.versions.libxml2)\usr\include\libxml2\libxml\tree.h",
        "openssl\lib64\libcrypto.lib",
        "openssl\include\openssl\ssl.h",
        "sasl\lib64\sasl2.lib",
        "sasl\include\sasl\sasl.h",
        "zlib\lib64\zlib.lib",
        "zlib\lib64\zlib.dll",
        "zlib\include\zlib.h"
    )
}

function Assert-MailcoreDependenciesLayout {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)]$Pins
    )
    $missing = Get-MailcoreDependenciesRequiredFiles -Pins $Pins |
        Where-Object { -not (Test-Path -LiteralPath (Join-Path $Root $_)) }
    if ($missing) {
        throw "The dependency archive unpacked at $Root is missing:`n  $($missing -join "`n  ")"
    }
}

# Returns a local path to the dependency archive, downloading it from the release when needed.
# It is a public asset, so no credentials are involved.
function Get-MailcoreDependenciesArchive {
    param(
        [Parameter(Mandatory = $true)][string]$WorkPath,
        [Parameter(Mandatory = $true)]$Pins
    )
    $name = $Pins.dependenciesArchive
    $path = Join-Path $WorkPath $name
    if (Test-Path -LiteralPath $path) { return $path }

    New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null
    $url = Get-MailcorePrebuiltUrl -ArchiveName $name
    Write-TaskLog "Downloading $name"
    try {
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    }
    catch {
        Remove-Item -LiteralPath $path -Force -ErrorAction Ignore
        throw @"
Could not download the dependency archive $name from $url

It carries the binary build inputs (ICU, libxml2, openssl, sasl, zlib) and is attached to the
$Script:MailcorePrebuiltReleaseTag release once, by hand. Attach it, or pass a local copy with
-PrebuiltDependenciesArchive <path>. New-DependenciesArchive.ps1 rebuilds it from scratch.

Download error: $($_.Exception.Message)
"@
    }
    return $path
}
