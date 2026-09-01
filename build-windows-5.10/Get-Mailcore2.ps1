Param(
    [string]$InstallPath
)

. "$PSScriptRoot\Prebuilt-Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"

if (-Not $InstallPath) {
    $InstallPath = "$ProjectRoot\.build\install"
}

# The archive is named after the content of the C/C++ sources, so this checkout already knows
# which one it needs - there is no version to keep in step. It is a public release asset, so
# downloading it takes no credential.
$PrebuiltMailcoreDigest = Get-MailcoreSourceDigest -RepoRoot $ProjectRoot
$PrebuiltMailcoreArchive = Get-MailcorePrebuiltArchiveName -Digest $PrebuiltMailcoreDigest
$PrebuiltMailcoreUrl = Get-MailcorePrebuiltUrl -ArchiveName $PrebuiltMailcoreArchive

Push-Task -Name "mailcore2" -ScriptBlock {
    Push-Task -Name "Initialize" -ScriptBlock {
        Write-TaskLog "Working in $ProjectRoot"
        Push-Location -Path $ProjectRoot
    }

    try {
        $TempDir = [System.IO.Path]::GetTempFileName()
        Remove-Item $TempDir
        
        $TempFile = "$TempDir.zip"
        
        Write-TaskLog "Downloading $PrebuiltMailcoreUrl to $TempFile"

        try {
            Invoke-RestMethod -Uri $PrebuiltMailcoreUrl -OutFile $TempFile
        }
        catch {
            throw @"
Prebuilt MailCore not found: $PrebuiltMailcoreArchive
Have you built and uploaded it yet?

These C/C++ sources (digest $PrebuiltMailcoreDigest) have no published Windows prebuilt.
On a Windows build machine, in a checkout at this exact revision, run:

    .\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1

Nothing needs to be committed afterwards - the archive is named after the sources, so this
revision will find it. To build the C++ from source instead, pass -BuildMailcore2 to
Build-SwiftMailcore.ps1.

Download error: $($_.Exception.Message)
"@
        }
        Remove-Item $TempDir -Force -Recurse -ErrorAction Ignore
        New-Item -ItemType Directory $TempDir
        Write-TaskLog "Extracting $TempFile to $TempDir"
        tar -C "$TempDir" -xf "$TempFile"
        
        $ArchiveDigest = Get-MailcoreArchiveDigest -UnpackedPath "$TempDir\mailcore2-all"
        if ($ArchiveDigest -ne $PrebuiltMailcoreDigest) {
            throw "Prebuilt $PrebuiltMailcoreArchive was built from sources with digest '$ArchiveDigest', expected '$PrebuiltMailcoreDigest'. The published asset does not match its name."
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
