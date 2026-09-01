# Rebuilds mailcore2-windows-deps-<n>.zip, the archive of binary build inputs that
# Build-Mailcore2.ps1 consumes. It has never needed regenerating - this exists so the procedure
# is executable rather than prose, and so the layout it produces is checked against the one the
# build reads (Assert-MailcoreDependenciesLayout in Common.ps1).
#
# ICU and libxml2 are reproduced from their upstream releases. openssl, sasl and zlib are
# Readdle-built binaries with no public source of truth, so they are carried over from an
# existing archive (-BaseArchive) or from explicit paths.
#
#     .\windows\New-DependenciesArchive.ps1 -BaseArchive .\mailcore2-windows-deps-1.zip
#
# Publishing it is a separate, deliberate step:
#
#     .\windows\Publish-Mailcore2Prebuilt.ps1 -PublishDependenciesArchive <path>
#
# Bumping the archive means editing dependenciesArchive in pins.json, which changes the digest
# and asks every consumer for a new mailcore2-all archive. That is the intended behaviour.

Param(
    # An existing dependency archive to carry openssl, sasl and zlib over from.
    [string]$BaseArchive,
    # Or those three directories explicitly, in the layout Common.ps1 describes.
    [string]$OpenSslPath,
    [string]$SaslPath,
    [string]$ZlibPath,
    [string]$WorkPath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"
if (-Not $WorkPath) { $WorkPath = "$ProjectRoot\.build\deps-archive" }

$Pins = Get-MailcorePins
$Layout = Get-MailcoreDependenciesLayout -Pins $Pins

$IcuVersion = $Pins.versions.icu
$IcuUnderscored = $IcuVersion.Replace(".", "_")
$IcuTag = "release-" + $IcuVersion.Replace(".", "-")
$IcuUrl = "https://github.com/unicode-org/icu/releases/download/$IcuTag/icu4c-$IcuUnderscored-Win64-MSVC2019.zip"

$LibXml2Version = $Pins.versions.libxml2
$LibXml2Series = ($LibXml2Version -split "\.")[0..1] -join "."
$LibXml2Url = "https://download.gnome.org/sources/libxml2/$LibXml2Series/libxml2-$LibXml2Version.tar.xz"

$StageRoot = "$WorkPath\mailcore2-windows-deps"
if (-Not $OutputPath) { $OutputPath = "$WorkPath\$($Pins.dependenciesArchive)" }

if (-not $BaseArchive -and -not ($OpenSslPath -and $SaslPath -and $ZlibPath)) {
    throw "Pass -BaseArchive <existing deps zip>, or all three of -OpenSslPath, -SaslPath and -ZlibPath. openssl, sasl and zlib are prebuilt binaries that cannot be regenerated here."
}

Push-Task -Name "Prepare" -ScriptBlock {
    if (Test-Path -LiteralPath $StageRoot) { Remove-Item -LiteralPath $StageRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $StageRoot -Force | Out-Null
    Invoke-VsDevCmd -Version "2022"
    Initialize-Toolchain
}

# --- ICU: the official Win64 distribution, relaid under usr/ ----------------------------------

Push-Task -Name "ICU $IcuVersion" -ScriptBlock {
    $zip = "$WorkPath\icu4c-$IcuUnderscored.zip"
    $unpacked = "$WorkPath\icu-unpacked"
    if (-not (Test-Path -LiteralPath $zip)) {
        Write-TaskLog "Downloading $IcuUrl"
        Invoke-WebRequest -Uri $IcuUrl -OutFile $zip -UseBasicParsing
    }
    if (Test-Path -LiteralPath $unpacked) { Remove-Item -LiteralPath $unpacked -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $unpacked -Force

    # The distribution keeps 64-bit output in bin64/lib64; the build wants usr/bin and
    # usr/lib/x64 (which is how the CMake arguments in Build-Mailcore2.ps1 spell it).
    $usr = Join-Path $StageRoot $Layout.Icu
    New-Item -ItemType Directory -Path "$usr\bin", "$usr\lib\x64", "$usr\include" -Force | Out-Null
    Copy-Item "$unpacked\bin64\*" "$usr\bin" -Recurse -Force
    Copy-Item "$unpacked\lib64\*" "$usr\lib\x64" -Recurse -Force
    Copy-Item "$unpacked\include\*" "$usr\include" -Recurse -Force
}

# --- libxml2: built from source, static, with everything optional switched off ----------------

Push-Task -Name "libxml2 $LibXml2Version" -ScriptBlock {
    $tarball = "$WorkPath\libxml2-$LibXml2Version.tar.xz"
    $sourceRoot = "$WorkPath\libxml2-src"
    if (-not (Test-Path -LiteralPath $tarball)) {
        Write-TaskLog "Downloading $LibXml2Url"
        Invoke-WebRequest -Uri $LibXml2Url -OutFile $tarball -UseBasicParsing
    }
    if (Test-Path -LiteralPath $sourceRoot) { Remove-Item -LiteralPath $sourceRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
    tar -C $sourceRoot -xf $tarball
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract $tarball" }

    $source = "$sourceRoot\libxml2-$LibXml2Version"
    $prefix = "$WorkPath\libxml2-install"
    if (Test-Path -LiteralPath $prefix) { Remove-Item -LiteralPath $prefix -Recurse -Force }

    # mailcore2 links libxml2 statically and uses none of its optional backends.
    $cmakeArgs =
        "-G Ninja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_INSTALL_PREFIX=$prefix",
        "-DLIBXML2_WITH_ICONV=OFF",
        "-DLIBXML2_WITH_ICU=OFF",
        "-DLIBXML2_WITH_LZMA=OFF",
        "-DLIBXML2_WITH_MODULES=OFF",
        "-DLIBXML2_WITH_PROGRAMS=OFF",
        "-DLIBXML2_WITH_PYTHON=OFF",
        "-DLIBXML2_WITH_TESTS=OFF",
        "-DLIBXML2_WITH_ZLIB=OFF"
    Invoke-CMakeTasks -WorkingDir $source -CMakeArgs ($cmakeArgs -join " ")

    # CMake installs headers under include/libxml2/libxml and the archive under lib/. The build
    # passes -DLIBXML_INCLUDE_DIR=<usr>\include and -DLIBXML_LIBRARY=<usr>\lib\x64\libxml2s.lib,
    # so both move up a level.
    $usr = Join-Path $StageRoot $Layout.LibXml2
    New-Item -ItemType Directory -Path "$usr\include", "$usr\lib\x64" -Force | Out-Null
    Copy-Item "$prefix\include\libxml2\*" "$usr\include" -Recurse -Force
    Get-ChildItem "$prefix\lib" -Filter *.lib -File | Copy-Item -Destination "$usr\lib\x64" -Force
}

# --- openssl, sasl, zlib: carried over --------------------------------------------------------

Push-Task -Name "openssl, sasl, zlib" -ScriptBlock {
    if ($BaseArchive) {
        $base = "$WorkPath\base"
        if (Test-Path -LiteralPath $base) { Remove-Item -LiteralPath $base -Recurse -Force }
        New-Item -ItemType Directory -Path $base -Force | Out-Null
        Expand-Archive -Path "$(Resolve-Path $BaseArchive)" -DestinationPath $base -Force
        $baseRoot = "$base\mailcore2-windows-deps"
        if (-not (Test-Path -LiteralPath $baseRoot)) {
            throw "$BaseArchive does not contain a single top-level mailcore2-windows-deps directory"
        }
        $Script:OpenSslPath = Join-Path $baseRoot $Layout.OpenSsl
        $Script:SaslPath = Join-Path $baseRoot $Layout.Sasl
        $Script:ZlibPath = Join-Path $baseRoot $Layout.Zlib
    }

    foreach ($entry in @{ $Layout.OpenSsl = $OpenSslPath; $Layout.Sasl = $SaslPath; $Layout.Zlib = $ZlibPath }.GetEnumerator()) {
        $source = "$(Resolve-Path $entry.Value)"
        Write-TaskLog "$($entry.Key) from $source"
        Copy-Item $source (Join-Path $StageRoot $entry.Key) -Recurse -Force
    }
}

# --- Verify against the layout the build reads, then package ----------------------------------

Push-Task -Name "Verify layout" -ScriptBlock {
    Assert-MailcoreDependenciesLayout -Root $StageRoot -Pins $Pins
    Write-TaskLog "Layout matches what Build-Mailcore2.ps1 expects"
}

Push-Task -Name "Package" -ScriptBlock {
    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
    tar.exe -a -cf $OutputPath -C $WorkPath mailcore2-windows-deps
    if ($LASTEXITCODE -ne 0) { throw "Packaging failed" }
}

Write-Host ""
Write-Host "Built $OutputPath" -ForegroundColor Green
Write-Host "  sha256: $((Get-FileHash $OutputPath -Algorithm SHA256).Hash)" -ForegroundColor Green
Write-Host ""
Write-Host "Publish it with:" -ForegroundColor Green
Write-Host "    .\windows\Publish-Mailcore2Prebuilt.ps1 -PublishDependenciesArchive $OutputPath"
Write-Host ""
