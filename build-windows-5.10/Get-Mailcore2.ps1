Param(
    [string]$InstallPath,
    # Legacy S3 flow, kept for tags published before the move to release assets.
    [int]$LegacyS3Version = 0
)

. "$PSScriptRoot\Prebuilt-Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"

if (-Not $InstallPath) {
    $InstallPath = "$ProjectRoot\.build\install"
}

Push-Task -Name "mailcore2" -ScriptBlock {
    Push-Task -Name "Initialize" -ScriptBlock {
        Write-TaskLog "Working in $ProjectRoot"
        Push-Location -Path $ProjectRoot
    }

    try {
        $ExpectedDigest = $null

        if ($LegacyS3Version -gt 0) {
            $ArchiveName = "mailcore2-all-$LegacyS3Version.zip"
            $ArchiveUrl = "https://spark-prebuilt-binaries.s3.amazonaws.com/$ArchiveName"
            $S3Key = $env:SPARK_PREBUILT_KEY
            if (!$S3Key) {
                throw "Spark prebuilt storage key(SPARK_PREBUILT_KEY) is required for -LegacyS3Version"
            }
        }
        else {
            $ExpectedDigest = Get-MailcoreSourceDigest -RepoRoot $ProjectRoot
            $ArchiveName = Get-MailcorePrebuiltArchiveName -Digest $ExpectedDigest
            $ArchiveUrl = Get-MailcorePrebuiltUrl -ArchiveName $ArchiveName
            $S3Key = $null
        }

        $TempDir = [System.IO.Path]::GetTempFileName()
        Remove-Item $TempDir

        $TempFile = "$TempDir.zip"

        Write-TaskLog "Downloading $ArchiveUrl to $TempFile"

        try {
            if ($S3Key) {
                Invoke-RestMethod -Uri $ArchiveUrl -OutFile $TempFile -UserAgent $S3Key
            }
            else {
                # Public repository: release assets download without any credentials.
                Invoke-RestMethod -Uri $ArchiveUrl -OutFile $TempFile
            }
        }
        catch {
            if ($LegacyS3Version -gt 0) { throw }
            throw @"
Prebuilt MailCore not found: $ArchiveName
Have you built and uploaded it yet?

These C/C++ sources (digest $ExpectedDigest) have no published Windows prebuilt.
In a mailcore2 checkout at this exact revision, on a Windows machine, run:

    .\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1

Nothing needs to be committed to mailcore2 afterwards - the archive is named after the
sources, so this revision will find it. To build the C++ from source instead, pass
-BuildMailcore2 to Build-SwiftMailcore.ps1.

Download error: $($_.Exception.Message)
"@
        }

        Remove-Item $TempDir -Force -Recurse -ErrorAction Ignore
        New-Item -ItemType Directory $TempDir
        Write-TaskLog "Extracting $TempFile to $TempDir"
        tar -C "$TempDir" -xf "$TempFile"

        if ($ExpectedDigest) {
            # The name says which sources this archive belongs to; the stamp inside proves it.
            $ArchiveDigest = Get-MailcoreArchiveDigest -UnpackedPath "$TempDir\mailcore2-all"
            if ($ArchiveDigest -ne $ExpectedDigest) {
                throw "Prebuilt $ArchiveName was built from sources with digest '$ArchiveDigest', expected '$ExpectedDigest'. The published asset does not match its name - rebuild and replace it."
            }
        }

        New-Item -Path $InstallPath -ItemType Directory -ErrorAction Ignore
        Get-ChildItem -Path "$TempDir\mailcore2-all" | Copy-Item -Destination $InstallPath -Recurse -Container -PassThru -Force | Write-Host

        Write-TaskLog "Deleting $TempFile"
        Remove-Item $TempFile -Force
        Write-TaskLog "Deleting $TempDir"
        Remove-Item $TempDir -Force -Recurse
    }
    finally {
        Push-Task -Name "Shutdown" -ScriptBlock {
            Pop-Location
        }
    }
}
