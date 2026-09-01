# Shared helpers for the Windows prebuilt flow: where the prebuilt archives live and how the
# C/C++ sources they were built from are identified.
#
# The archive name is derived from the content of the sources, not from a version number, so
# there is nothing to bump and nothing to forget: sources that were never built simply have no
# archive, and the build says so.

$Script:MailcorePrebuiltRepo = "readdle/mailcore2"
$Script:MailcorePrebuiltReleaseTag = "windows-prebuilt"
$Script:MailcorePrebuiltUrlBase = "https://github.com/$Script:MailcorePrebuiltRepo/releases/download/$Script:MailcorePrebuiltReleaseTag"

# The RD modules are internal; without them the local fallback provides the subset this build
# needs, so a plain clone of the public repository is enough.
$Script:RequiredRDModules = "RDBuildCMake", "RDBuildMSVC", "RDDependency"
if ($Script:RequiredRDModules | Where-Object { -not (Get-Module -ListAvailable $_) }) {
    . "$PSScriptRoot\Build-Helpers.ps1"
}
else {
    Import-Module RDBuildCMake
    Import-Module RDBuildMSVC
    Import-Module RDDependency
}

function Get-MailcorePinsPath {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    return (Join-Path $RepoRoot "windows-build-pins.json")
}

function Get-MailcorePins {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $path = Get-MailcorePinsPath -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $path)) { throw "Build pins not found: $path" }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

# Everything that determines the content of the prebuilt binaries: the C/C++ sources (Swift is
# compiled from source at build time, so src/swift is excluded) plus the pins for the bundled
# dependencies and the toolchain. Deliberately NOT the build scripts - editing them would
# invalidate perfectly good binaries.
function Get-MailcoreDigestPathSpec {
    return @("src", "CMakeLists.txt", "windows-build-pins.json")
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
    if (-not $lines) { throw "No source entries found in $RepoRoot - wrong directory?" }

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

# The release is a permanent container for binaries, set up once by hand. Nothing here creates
# it; the scripts only add archives to it.
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

# The digest of the sources an unpacked archive was built from.
function Get-MailcoreArchiveDigest {
    param([Parameter(Mandatory = $true)][string]$UnpackedPath)
    $stamp = Join-Path $UnpackedPath "etc\mailcore2-source-digest"
    if (-not (Test-Path -LiteralPath $stamp)) { return $null }
    return (Get-Content -LiteralPath $stamp -Raw).Trim()
}
