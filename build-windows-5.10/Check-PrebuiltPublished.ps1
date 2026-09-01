# Answers one question: do the C/C++ sources in this checkout have a published Windows prebuilt?
#
# This is what the Windows pull-request check runs. It builds nothing and needs no Windows - the
# digest is a hash of git tree entries, identical on every platform - so a Linux runner answers
# in seconds.

Param(
    # Defaults to whatever is checked out, which on a pull request is the merge result: that is
    # what lands on the base branch and gets tagged.
    [string]$Ref = "HEAD"
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Prebuilt-Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"
$Readme = "https://github.com/$Script:MailcorePrebuiltRepo/blob/spark2/README.md#windows-prebuilt"

function Get-ArchiveFor {
    param([string]$AtRef)
    return Get-MailcorePrebuiltArchiveName -Digest (Get-MailcoreSourceDigest -RepoRoot $ProjectRoot -Ref $AtRef)
}

if (-not (Test-MailcorePrebuiltRelease)) {
    Write-Host ""
    Write-Host $Script:MailcoreReleaseSetupHelp -ForegroundColor Red
    Write-Host ""
    Write-Host "::error title=Windows prebuilt release missing::The $Script:MailcorePrebuiltReleaseTag release does not exist. It is created once, by hand."
    exit 1
}

$Archive = Get-ArchiveFor -AtRef $Ref
$Published = Get-MailcoreReleaseAssetNames

Write-Host ""
Write-Host "  commit  : $((& git -C $ProjectRoot rev-parse $Ref).Trim())" -ForegroundColor Cyan
Write-Host "  archive : $Archive" -ForegroundColor Cyan
Write-Host ""

if ($Published -contains $Archive) {
    Write-Host "Published. These sources have a Windows prebuilt." -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host "There is no Windows prebuilt for these sources: $Archive" -ForegroundColor Red
Write-Host "Have you built and uploaded it yet?" -ForegroundColor Red
Write-Host ""

# On a merge commit the second parent is the pull request head - what a developer would have
# published from. When the two differ the base has moved, and saying so beats an unexplained red.
$parentLine = (& git -C $ProjectRoot rev-list --parents -n 1 $Ref 2>$null)
$parents = @("$parentLine".Trim() -split "\s+" | Where-Object { $_ })
$headArchive = if ($parents.Count -ge 3) { Get-ArchiveFor -AtRef $parents[2] } else { $Archive }

if ($headArchive -ne $Archive -and ($Published -contains $headArchive)) {
    Write-Host "Your branch head has one ($headArchive), so the base branch moved after you" -ForegroundColor Yellow
    Write-Host "published. Rebase onto the base branch and publish again from the rebased head." -ForegroundColor Yellow
}
else {
    Write-Host "If not: on the Windows build machine, in a checkout of this branch," -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    .\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1"
    Write-Host ""
    Write-Host "and re-run this check. Publishing commits nothing - the archive is named after the" -ForegroundColor Yellow
    Write-Host "sources, so this revision will find it." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "How this works: $Readme" -ForegroundColor DarkGray
Write-Host ""
Write-Host "::error title=Windows prebuilt missing::No $Archive published - have you built and uploaded it yet? See $Readme"
exit 1
