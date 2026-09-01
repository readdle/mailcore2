Param(
    # Local copy of the dependency archive. Downloaded from the release when omitted.
    [string]$PrebuiltDependenciesArchive,
    [string]$WorkPath,
    # Publish the dependency archive itself (build inputs: ICU, libxml2, openssl, sasl, zlib).
    [string]$PublishDependenciesArchive,
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

function Test-ReleaseAsset {
    param([Parameter(Mandatory = $true)][string]$AssetName)
    $assets = & gh release view $Script:MailcorePrebuiltReleaseTag --repo $Script:MailcorePrebuiltRepo --json assets --jq ".assets[].name" 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }   # no release yet
    return ($assets -contains $AssetName)
}

function Publish-ReleaseAsset {
    param([Parameter(Mandatory = $true)][string]$Path)
    $exists = & gh release view $Script:MailcorePrebuiltReleaseTag --repo $Script:MailcorePrebuiltRepo --json tagName 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-TaskLog "Creating release $Script:MailcorePrebuiltReleaseTag"
        & gh release create $Script:MailcorePrebuiltReleaseTag --repo $Script:MailcorePrebuiltRepo --prerelease `
            --title "Windows prebuilt binaries" `
            --notes "Container for the Windows prebuilt archives. Not a code release: mailcore2-all-<digest>.zip is named after the C/C++ sources it was built from, mailcore2-windows-deps-<n>.zip carries the build inputs."
        if ($LASTEXITCODE -ne 0) { throw "Failed to create release $Script:MailcorePrebuiltReleaseTag" }
    }
    & gh release upload $Script:MailcorePrebuiltReleaseTag $Path --repo $Script:MailcorePrebuiltRepo
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload $Path" }
}

# --- Publishing only the dependency archive -------------------------------------------------

if ($PublishDependenciesArchive) {
    Assert-GitHubCli
    $depsPath = "$(Resolve-Path $PublishDependenciesArchive)"
    $depsName = Split-Path $depsPath -Leaf
    if (Test-ReleaseAsset -AssetName $depsName) {
        Write-Host "$depsName is already published - nothing to do." -ForegroundColor Green
        return
    }
    Publish-ReleaseAsset -Path $depsPath
    Write-Host "Uploaded $depsName" -ForegroundColor Green
    return
}

# --- Preflight ------------------------------------------------------------------------------

if (-not $SkipUpload) { Assert-GitHubCli }

$Pins = Get-MailcorePins -RepoRoot $ProjectRoot

# Throws when the digested paths are dirty: the archive must correspond to a committed state.
$Digest = Get-MailcoreSourceDigest -RepoRoot $ProjectRoot
$ArchiveName = Get-MailcorePrebuiltArchiveName -Digest $Digest
$GitRev = (& git -C $ProjectRoot rev-parse HEAD).Trim()

Write-Host ""
Write-Host "  source digest : $Digest" -ForegroundColor Cyan
Write-Host "  archive       : $ArchiveName" -ForegroundColor Cyan
Write-Host "  git revision  : $GitRev" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipUpload -and (Test-ReleaseAsset -AssetName $ArchiveName)) {
    Write-Host "These sources already have a published prebuilt ($ArchiveName) - nothing to do." -ForegroundColor Green
    return
}

Push-Task -Name "Verify toolchain against windows-build-pins.json" -ScriptBlock {
    $toolsetRoot = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\$($Pins.toolchain.msvcToolset)"
    if (-not (Test-Path -LiteralPath $toolsetRoot)) {
        throw "MSVC toolset $($Pins.toolchain.msvcToolset) not found at $toolsetRoot. Install it, or update windows-build-pins.json (which changes the digest and therefore the archive name)."
    }
    $sdkRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\$($Pins.toolchain.windowsSdk)"
    if (-not (Test-Path -LiteralPath $sdkRoot)) {
        throw "Windows SDK $($Pins.toolchain.windowsSdk) not found at $sdkRoot. Install it, or update windows-build-pins.json."
    }
    $swiftPlatform = Join-Path $env:LOCALAPPDATA "Programs\Swift\Platforms\$($Pins.toolchain.swift)"
    if (-not (Test-Path -LiteralPath $swiftPlatform)) {
        throw "Swift $($Pins.toolchain.swift) not found at $swiftPlatform. Install it, or update windows-build-pins.json."
    }
    if (-not $env:SDKROOT) {
        $env:SDKROOT = Join-Path $swiftPlatform "Windows.platform\Developer\SDKs\Windows.sdk"
        Write-TaskLog "SDKROOT was unset, using $env:SDKROOT"
    }
    Write-TaskLog "Toolchain matches the pins"
}

# --- Dependency archive ---------------------------------------------------------------------

$DependenciesPath = "$WorkPath\build-dependencies"
$InstallPath = "$WorkPath\mailcore2-install"
$StagePath = "$WorkPath\mailcore2-all"
$ArchivePath = "$WorkPath\$ArchiveName"

New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null

if (-not $PrebuiltDependenciesArchive) {
    $depsName = $Pins.dependenciesArchive
    $PrebuiltDependenciesArchive = "$WorkPath\$depsName"
    if (-not (Test-Path -LiteralPath $PrebuiltDependenciesArchive)) {
        $depsUrl = Get-MailcorePrebuiltUrl -ArchiveName $depsName
        Push-Task -Name "Download $depsName" -ScriptBlock {
            try {
                Invoke-RestMethod -Uri $depsUrl -OutFile $PrebuiltDependenciesArchive
            }
            catch {
                throw "Could not download the dependency archive $depsName from $depsUrl. Publish it once with -PublishDependenciesArchive <path>, or pass -PrebuiltDependenciesArchive <path> to use a local copy.`n$($_.Exception.Message)"
            }
        }
    }
}

# --- Build ------------------------------------------------------------------------------------

Push-Task -Name "Build mailcore2" -ScriptBlock {
    & "$PSScriptRoot\Build-Mailcore2.ps1" `
        -DependenciesPath $DependenciesPath `
        -InstallPath $InstallPath `
        -PrebuiltDependenciesArchive $PrebuiltDependenciesArchive `
        -Install
    if ($LASTEXITCODE -ne 0) { throw "Build-Mailcore2.ps1 failed" }
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
        "icuuc69.dll", "icuin69.dll", "icudt69.dll",
        "dispatch.dll", "BlocksRuntime.dll",
        "msvcp140.dll", "vcruntime140.dll"
    )
    $missing = $required | Where-Object { -not (Test-Path -LiteralPath "$checkDir\mailcore2-all\bin\$_") }
    if ($missing) { throw "The archive is missing: $($missing -join ', ')" }

    $requiredHeaders = @("include\CMailCore\CIMAPAsyncConnection.h", "include\MailCore\MCIMAPAsyncConnection.h")
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
    Publish-ReleaseAsset -Path $ArchivePath
}

Write-Host ""
Write-Host "Published $ArchiveName" -ForegroundColor Green
Write-Host "  sources : $Digest" -ForegroundColor Green
Write-Host "  revision: $GitRev" -ForegroundColor Green
Write-Host "  sha256  : $((Get-FileHash $ArchivePath -Algorithm SHA256).Hash)" -ForegroundColor Green
Write-Host ""
Write-Host "Nothing needs to be committed to mailcore2: the archive is named after these sources," -ForegroundColor Green
Write-Host "so any checkout of them finds it. Carry on with the commit, PR and tag as usual." -ForegroundColor Green
