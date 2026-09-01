Param(
    [string]$DependenciesPath,
    [string]$InstallPath,
    [switch]$Install = $false,
    [switch]$BuildMailcore2 = $false
)

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"

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

$IcuVersionMajor = "69"
$IcuVersion = "$IcuVersionMajor.1"
$LibXml2Version = "2.11.5"
$IcuPath = "C:\Library\icu-$IcuVersion\usr"
$LibXml2Path = "C:\Library\libxml2-$LibXml2Version\usr"

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
        & $PSScriptRoot\Build-Mailcore2.ps1 -InstallPath $InstallPath -DependenciesPath $DependenciesPath -Install
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
