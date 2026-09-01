# Shared by the scripts that deal with the prebuilt archives: where they live, and how the C/C++
# sources they were built from are identified.
#
# The archive name is derived from the content of the sources, not from a version number, so
# there is nothing to bump and nothing to forget: sources that were never built simply have no
# archive, and the build says so.
#
# Nothing here touches the build itself. Build-Mailcore2.ps1 works exactly as it always has; the
# only reason it dot-sources this file is to fetch its binary dependencies from the release
# instead of from S3.

$Script:MailcorePrebuiltRepo = "readdle/mailcore2"
$Script:MailcorePrebuiltReleaseTag = "windows-prebuilt"
$Script:MailcorePrebuiltUrlBase = "https://github.com/$Script:MailcorePrebuiltRepo/releases/download/$Script:MailcorePrebuiltReleaseTag"

# The binaries this build links against. It sits in a digested file, so replacing the archive
# changes the digest and every consumer asks for a rebuilt prebuilt - which is right, because
# these three libraries end up inside it.
$Script:MailcoreDependenciesArchive = "mailcore2-windows-deps-1.zip"

# Everything that determines the content of the prebuilt binaries: the C/C++ sources (Swift is
# compiled from source at build time, so src/swift is excluded), the top-level CMakeLists, and
# this directory - the scripts decide what gets compiled, which project files and redistributables
# get copied in, and what ends up in the package.
#
# Including the scripts costs an occasional rebuild for a change that could not have altered a
# byte - a reworded message, a fix to the pull-request check. That is the safe direction to err
# in: the alternative is an archive whose contents changed under a name that did not.
function Get-MailcoreDigestPathSpec {
    return @("src", "CMakeLists.txt", "build-windows-5.10")
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

    # src/swift is outside the digest, so a dirty file there must not block it either.
    $status = @(& git -C $RepoRoot status --porcelain -- @paths | Where-Object { $_ -notmatch " src/swift/" })
    if ($LASTEXITCODE -ne 0) { throw "Not a git checkout: $RepoRoot" }
    if ($Ref -eq "HEAD" -and $status) {
        throw "Uncommitted changes under $($paths -join ', '): the digest describes HEAD, so it would not match what is built. Commit them, or build from source with -BuildMailcore2.`n$($status -join "`n")"
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
    return "mailcore2-windows-$($Digest.Substring(0, 12)).zip"
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

# --- The release --------------------------------------------------------------------------------

# The release is a permanent container for binaries, set up once by hand. Nothing here creates it;
# the scripts only add archives to it.
$Script:MailcoreReleaseSetupHelp = @"
The $Script:MailcorePrebuiltReleaseTag release does not exist, or is not visible to this token.
It is created once, by hand:

  1. https://github.com/$Script:MailcorePrebuiltRepo/releases/new?tag=$Script:MailcorePrebuiltReleaseTag
     Tag $Script:MailcorePrebuiltReleaseTag, marked as a pre-release.
  2. Attach the dependency archive to it, under the name Prebuilt-Common.ps1 gives it.
"@

function Test-MailcorePrebuiltRelease {
    & gh release view $Script:MailcorePrebuiltReleaseTag --repo $Script:MailcorePrebuiltRepo --json tagName 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Assert-MailcorePrebuiltRelease {
    if (-not (Test-MailcorePrebuiltRelease)) { throw $Script:MailcoreReleaseSetupHelp }
}

# Names of every asset on the release, or an empty array when there is no release. Needs gh on
# PATH and authenticated (GH_TOKEN is enough in CI).
function Get-MailcoreReleaseAssetNames {
    $assets = & gh release view $Script:MailcorePrebuiltReleaseTag --repo $Script:MailcorePrebuiltRepo --json assets --jq ".assets[].name" 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($assets)
}

function Test-MailcoreReleaseAsset {
    param([Parameter(Mandatory = $true)][string]$AssetName)
    return ((Get-MailcoreReleaseAssetNames) -contains $AssetName)
}

# --- The dependency archive ---------------------------------------------------------------------

# openssl, sasl and zlib: the three binaries that used to be fetched from S3, one zip each, with
# SPARK_PREBUILT_KEY. They now travel as one public asset on the release, unchanged, under a
# single top-level mailcore2-windows-deps directory. Nothing else moved: ICU and libxml2 come
# with the toolchain and were never in that bucket.
#
# Returns a local path, downloading the archive when there is not one already.
function Get-MailcoreDependenciesArchive {
    param([Parameter(Mandatory = $true)][string]$WorkPath)

    $name = $Script:MailcoreDependenciesArchive
    $path = Join-Path $WorkPath $name
    if (Test-Path -LiteralPath $path) { return $path }

    New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null
    $url = Get-MailcorePrebuiltUrl -ArchiveName $name
    Write-Host "Downloading $name"
    try {
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    }
    catch {
        Remove-Item -LiteralPath $path -Force -ErrorAction Ignore
        throw @"
Could not download the dependency archive $name from $url

It carries openssl, sasl and zlib, and is attached to the $Script:MailcorePrebuiltReleaseTag
release by hand, once. Attach it, or pass -PrebuiltDependenciesArchive <path> to use a local copy.

Download error: $($_.Exception.Message)
"@
    }
    return $path
}
