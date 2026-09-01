# Compiles the Swift bindings (src/swift) on top of the mailcore2 C/C++ libraries. By default
# those come from the published prebuilt archive; -BuildMailcore2 compiles them from source
# instead. This is the entry point spark-core calls.

Param(
    [string]$DependenciesPath,
    [string]$InstallPath,
    # Local copy of the dependency archive, forwarded to Build-Mailcore2.ps1.
    [string]$PrebuiltDependenciesArchive,
    [switch]$Install = $false,
    [switch]$BuildMailcore2 = $false
)

. "$PSScriptRoot\Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"
if (-Not $DependenciesPath) {
    $DependenciesPath = "$ProjectRoot\.build\Dependencies"
}

$SourceFiles = Get-ChildItem -Path "$ProjectRoot\src\swift\*.swift" -Recurse -File 
$ResourcesPath = "$ProjectRoot\resources"

$ModuleName = "MailCore"
$IntermediatesPath = "$ProjectRoot\.build\$ModuleName\Intermediates"
$ProductsPath = "$ProjectRoot\.build\$ModuleName"
if (-Not $InstallPath) {
    $InstallPath = "$ProjectRoot\.build\install"
}

$BinDir = "$InstallPath\bin"
$IncludeDir = "$InstallPath\include"
$LibDir = "$InstallPath\lib"
$BundleResourcesDir = "$BinDir\$ModuleName.resources"

$Pins = Get-MailcorePins
$Layout = Get-MailcoreDependenciesLayout -Pins $Pins
$PrebuiltRoot = "$DependenciesPath\mailcore2-windows-deps"

# Prefer the unpacked dependency archive when it is there (any machine that has run
# Build-Mailcore2.ps1), and fall back to the hand-made C:\Library layout of the CI image.
$IcuPath = "$PrebuiltRoot\$($Layout.Icu)"
if (-not (Test-Path -LiteralPath $IcuPath)) {
    $IcuPath = "C:\Library\icu-$($Pins.versions.icu)\usr"
}

$SwiftIncludePaths = 
    "$InstallPath\include"

$HeaderSearchPaths = 
    "$ProjectRoot\Externals\include",
    "$IcuPath\include"

$LibrarySearchPaths = 
    "$ProjectRoot\Externals\lib64",
    "$InstallPath\lib"

$Configuration = @{
    ModuleName = $ModuleName

    WorkPath = $ProjectRoot

    IntermediatesPath = $IntermediatesPath
    ProductsPath = $ProductsPath

    SwiftVersion = 5
    EnableTesting = $false
    BuildType = "Release"

    SwiftIncludePaths = $SwiftIncludePaths
    HeaderSearchPaths = $HeaderSearchPaths
    LibrarySearchPaths = $LibrarySearchPaths

    SourceFiles = $SourceFiles

    Libraries = "libetpan"
}

Push-Task -Name $ModuleName -ScriptBlock {
    Push-Task -Name "Initialize" -ScriptBlock {
        Invoke-VsDevCmd -Version "2022"

        Initialize-SDK
        Initialize-Toolchain
    }

    if ($BuildMailcore2) {
        & $PSScriptRoot\Build-Mailcore2.ps1 -InstallPath $InstallPath -DependenciesPath $DependenciesPath `
            -PrebuiltDependenciesArchive $PrebuiltDependenciesArchive -Install
    }
    else {
        & $PSScriptRoot\Get-Mailcore2.ps1 -InstallPath $InstallPath
    }

    Invoke-BuildModuleTarget -Configuration $Script:Configuration

    if ($Install) {
        Push-Task -Name "Install" -ScriptBlock {
            Copy-Item -Path "$ProductsPath\$ModuleName.lib" -Destination $LibDir -Force -ErrorAction Stop
            Copy-Item -Path "$ProductsPath\$ModuleName.swiftdoc" -Destination $IncludeDir -Force -ErrorAction Stop
            Copy-Item -Path "$ProductsPath\$ModuleName.swiftmodule" -Destination $IncludeDir -Force -ErrorAction Stop
            Copy-Item -Path "$ProductsPath\$ModuleName.dll" -Destination $BinDir -Force -ErrorAction Stop
            Install-File "$ResourcesPath\providers.json" -Destination $BundleResourcesDir
        }
    }
 
}
