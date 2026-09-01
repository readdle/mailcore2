# Downloads the prebuilt C/C++ archive that belongs to the sources in this checkout and lays it
# out in $InstallPath. Called by Build-SwiftMailcore.ps1, which then compiles only src/swift on
# top of it. No credentials: the release assets are public.

Param(
    [string]$InstallPath
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
        $ExpectedDigest = Get-MailcoreSourceDigest -RepoRoot $ProjectRoot
        $ArchiveName = Get-MailcorePrebuiltArchiveName -Digest $ExpectedDigest
        $ArchiveUrl = Get-MailcorePrebuiltUrl -ArchiveName $ArchiveName

        $TempDir = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
        $TempFile = "$TempDir.zip"

        try {
            Write-TaskLog "Downloading $ArchiveUrl"
            try {
                Invoke-WebRequest -Uri $ArchiveUrl -OutFile $TempFile -UseBasicParsing
            }
            catch {
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

            New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
            Write-TaskLog "Extracting to $TempDir"
            tar -C "$TempDir" -xf "$TempFile"
            if ($LASTEXITCODE -ne 0) { throw "Failed to extract $ArchiveName" }

            # The name says which sources this archive belongs to; the stamp inside proves it.
            $ArchiveDigest = Get-MailcoreArchiveDigest -UnpackedPath "$TempDir\mailcore2-all"
            if ($ArchiveDigest -ne $ExpectedDigest) {
                throw "Prebuilt $ArchiveName was built from sources with digest '$ArchiveDigest', expected '$ExpectedDigest'. The published asset does not match its name - rebuild and replace it."
            }

            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
            Get-ChildItem -Path "$TempDir\mailcore2-all" |
                Copy-Item -Destination $InstallPath -Recurse -Container -Force -PassThru |
                Write-Host
        }
        finally {
            Remove-Item -LiteralPath $TempFile -Force -ErrorAction Ignore
            Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction Ignore
        }
    }
    finally {
        Push-Task -Name "Shutdown" -ScriptBlock {
            Pop-Location
        }
    }
}
