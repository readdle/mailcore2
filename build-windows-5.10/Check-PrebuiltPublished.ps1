# Answers one question: do the C/C++ sources in this checkout have a published Windows prebuilt?
#
# This is what the Windows pull-request check runs. It needs no Windows and no toolchain - the
# digest is a hash of git tree entries, so it is the same on every platform - which is why the
# job can be a minute on a Linux runner instead of a full build.
#
# On a pull request the interesting commit is the merge result, because that is what ends up on
# the base branch and gets tagged. The PR head is reported alongside it, since that is what a
# developer would have published from, and the two differ once the base moves.

Param(
    # Defaults to the merge result on a pull request, or to HEAD anywhere else.
    [string]$Ref = "HEAD",
    # Reported next to $Ref when the two differ. Defaults to the second parent of a merge
    # commit, which for refs/pull/N/merge is the PR head.
    [string]$CompareRef
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Prebuilt-Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"

function Get-DigestInfo {
    param([string]$AtRef)
    $digest = Get-MailcoreSourceDigest -RepoRoot $ProjectRoot -Ref $AtRef
    return [pscustomobject]@{
        Ref     = $AtRef
        Commit  = (& git -C $ProjectRoot rev-parse $AtRef).Trim()
        Digest  = $digest
        Archive = Get-MailcorePrebuiltArchiveName -Digest $digest
    }
}

if (-not $CompareRef) {
    # rev-list --parents prints "<commit> <parent1> [<parent2> ...]".
    $parents = @((& git -C $ProjectRoot rev-list --parents -n 1 $Ref).Trim() -split "\s+")
    if ($parents.Count -ge 3) { $CompareRef = $parents[2] }
}

$target = Get-DigestInfo -AtRef $Ref

# "No release" and "release without this archive" need different answers: the first is a
# one-time setup step nobody has done, the second is a build nobody has published.
if (-not (Test-MailcorePrebuiltRelease)) {
    Write-Host ""
    Write-Host $Script:MailcoreReleaseSetupHelp -ForegroundColor Red
    Write-Host ""
    if ($env:GITHUB_STEP_SUMMARY) {
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value @"
### Windows prebuilt: no release

``$($Script:MailcorePrebuiltReleaseTag)`` does not exist yet. It is created once, by hand, and the
dependency archive is attached to it once. Until then no prebuilt can be published at all.
"@
    }
    Write-Host "::error title=Windows prebuilt release missing::The $Script:MailcorePrebuiltReleaseTag release does not exist. It is created once, by hand."
    exit 1
}

$published = Get-MailcoreReleaseAssetNames

Write-Host ""
Write-Host "  commit  : $($target.Commit)" -ForegroundColor Cyan
Write-Host "  digest  : $($target.Digest)" -ForegroundColor Cyan
Write-Host "  archive : $($target.Archive)" -ForegroundColor Cyan
Write-Host ""

$readme = "https://github.com/$Script:MailcorePrebuiltRepo/blob/spark2/README.md#windows-prebuilt"

# GitHub renders this on the pull request page, so the answer is visible without opening logs.
function Write-Summary {
    param([string]$Markdown)
    if ($env:GITHUB_STEP_SUMMARY) {
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $Markdown
    }
}

if ($published -contains $target.Archive) {
    Write-Host "Published. These sources have a Windows prebuilt." -ForegroundColor Green
    Write-Host ""
    Write-Summary @"
### Windows prebuilt: published

``$($target.Archive)`` is on the [``$Script:MailcorePrebuiltReleaseTag``](https://github.com/$Script:MailcorePrebuiltRepo/releases/tag/$Script:MailcorePrebuiltReleaseTag) release. Nothing to do.
"@
    exit 0
}

# Not published. Whether the branch head has one changes the advice, so work that out first.
$compare = $null
if ($CompareRef) {
    $compare = Get-DigestInfo -AtRef $CompareRef
    if ($compare.Digest -eq $target.Digest) { $compare = $null }
}

$baseMoved = $compare -and ($published -contains $compare.Archive)

Write-Host "There is no Windows prebuilt for these sources: $($target.Archive)" -ForegroundColor Red
Write-Host "Have you built and uploaded it yet?" -ForegroundColor Red
Write-Host ""

if ($baseMoved) {
    Write-Host "The branch head has one ($($compare.Archive)), so it looks like the base branch" -ForegroundColor Yellow
    Write-Host "moved after you published and the merge result is now different sources." -ForegroundColor Yellow
    Write-Host "Rebase onto the base branch and publish again from the rebased head." -ForegroundColor Yellow
}
else {
    Write-Host "If not: on a Windows machine, in a checkout of this branch," -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    .\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1"
    Write-Host ""
    Write-Host "and re-run this check. Publishing commits nothing - the archive is named after" -ForegroundColor Yellow
    Write-Host "the sources, so this revision will find it." -ForegroundColor Yellow
    if ($compare) {
        Write-Host ""
        Write-Host "The merge result differs from your branch head ($($compare.Archive))," -ForegroundColor DarkGray
        Write-Host "because the base branch has moved. Rebase first and you publish once." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "How this works: $readme" -ForegroundColor DarkGray
Write-Host ""

$summary = if ($baseMoved) {
@"
### Windows prebuilt: missing

There is no ``$($target.Archive)`` on the [``$Script:MailcorePrebuiltReleaseTag``](https://github.com/$Script:MailcorePrebuiltRepo/releases/tag/$Script:MailcorePrebuiltReleaseTag) release.

Your branch head does have one (``$($compare.Archive)``), so the base branch moved after you
published and the merge result is different sources. **Rebase onto the base branch and publish
again from the rebased head.**

[How the Windows prebuilt works]($readme)
"@
}
else {
@"
### Windows prebuilt: missing

There is no ``$($target.Archive)`` on the [``$Script:MailcorePrebuiltReleaseTag``](https://github.com/$Script:MailcorePrebuiltRepo/releases/tag/$Script:MailcorePrebuiltReleaseTag) release.
**Have you built and uploaded it yet?** There is no Windows CI, so this is a manual step.

If not, on a Windows machine in a checkout of this branch:

``````powershell
.\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1
``````

Then re-run this check. Publishing commits nothing to mailcore2 - the archive is named after
the sources, so this revision will find it.

[How the Windows prebuilt works]($readme)
"@
}
Write-Summary $summary

# An annotation puts the question in the checks list, not only in the log.
Write-Host "::error title=Windows prebuilt missing::No $($target.Archive) published - have you built and uploaded it yet? See $readme"
exit 1
