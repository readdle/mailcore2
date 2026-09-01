Param(
    [string]$DependenciesPath,
    [string]$InstallPath,
    [string]$PrebuiltDependenciesArchive,
    [switch]$Install = $false
)

. "$PSScriptRoot\Common.ps1"

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\"")"
if (-Not $DependenciesPath) {
    $DependenciesPath = "$ProjectRoot\.build\Dependencies"
}
if (-Not $InstallPath) {
    $InstallPath = "$ProjectRoot\.build\install"
}

$BinDir = "$InstallPath\bin"
$IncludeDir = "$InstallPath\include"
$LibDir = "$InstallPath\lib"

$Pins = Get-MailcorePins
$IcuVersion = $Pins.versions.icu
$IcuVersionMajor = $IcuVersion.Split(".")[0]
$LibXml2Version = $Pins.versions.libxml2

$CTemplateDependencyDir = "CTemplate"
$CTemplateDependencyPath = "$DependenciesPath\$CTemplateDependencyDir"
$LibEtPanDependencyDir = "LibEtPan"
$LibEtPanDependencyPath = "$DependenciesPath\$LibEtPanDependencyDir"
$TidyDependencyDir = "TidyHTML5"
$TidyDependencyPath = "$DependenciesPath\$TidyDependencyDir"

# One public archive carries every binary build input (ICU, libxml2, openssl, sasl, zlib), so a
# bare machine needs no credentials and no manual C:\Library layout. Downloaded on demand when
# a local copy was not supplied.
if ($PrebuiltDependenciesArchive) {
    # Resolved before anything changes the working directory.
    $PrebuiltDependenciesArchive = "$(Resolve-Path $PrebuiltDependenciesArchive)"
}
$PrebuiltRoot = "$DependenciesPath\mailcore2-windows-deps"
$Layout = Get-MailcoreDependenciesLayout -Pins $Pins
$IcuPath = "$PrebuiltRoot\$($Layout.Icu)"
$LibXml2Path = "$PrebuiltRoot\$($Layout.LibXml2)"
$OpenSslDependencyPath = "$PrebuiltRoot\$($Layout.OpenSsl)"
$SaslDependencyPath = "$PrebuiltRoot\$($Layout.Sasl)"
$ZlibDependencyPath = "$PrebuiltRoot\$($Layout.Zlib)"

# Pinned to exact commits in pins.json: their build outputs ship inside the archive, so a
# moving branch would silently change what the published binaries contain.
$Dependencies = @(
    @{ Name = "CTemplate"; GitUrl = $Pins.dependencies.CTemplate.url; GitRevision = $Pins.dependencies.CTemplate.revision; Directory = $CTemplateDependencyDir; }
    @{ Name = "LibEtPan"; GitUrl = $Pins.dependencies.LibEtPan.url; GitRevision = $Pins.dependencies.LibEtPan.revision; Directory = $LibEtPanDependencyDir; }
    @{ Name = "Tidy HTML5"; GitUrl = $Pins.dependencies.TidyHTML5.url; GitRevision = $Pins.dependencies.TidyHTML5.revision; Directory = $TidyDependencyDir; }
)

Push-Task -Name "mailcore2" -ScriptBlock {
    Push-Task -Name "Initialize" -ScriptBlock {
        Write-TaskLog "Working in $ProjectRoot"
        Push-Location -Path $ProjectRoot
    }

    try {
        Initialize-MailcoreSdkRoot
        $SwiftSDKPath = $Env:SDKROOT
        if (-not (Test-Path $SwiftSDKPath)) {
            throw "SDK path is not set or invalid. Make sure you have SDKROOT environment variable specified correctly."
        }
        Write-TaskLog "Found Swift SDK: $SwiftSDKPath"

        Initialize-Dependencies -Path $Script:DependenciesPath -Dependencies $Script:Dependencies
        Push-Task -Name "Unpack binary dependencies" -ScriptBlock {
            if (-not $PrebuiltDependenciesArchive) {
                $Script:PrebuiltDependenciesArchive = Get-MailcoreDependenciesArchive -WorkPath $DependenciesPath -Pins $Pins
            }
            # A stale tree from an older archive must not survive: files it no longer contains
            # would otherwise still be linked in.
            if (Test-Path -LiteralPath $PrebuiltRoot) { Remove-Item -LiteralPath $PrebuiltRoot -Recurse -Force }
            Write-TaskLog "Extracting $PrebuiltDependenciesArchive"
            Expand-Archive -Path $PrebuiltDependenciesArchive -DestinationPath $DependenciesPath -Force
            Assert-MailcoreDependenciesLayout -Root $PrebuiltRoot -Pins $Pins
        }
        
        Push-Task -Name "Prepare Build Environment" -ScriptBlock {
            Write-TaskLog "Configuring VS environment"
            Invoke-VsDevCmd -Version "2022"
            Initialize-Toolchain
        }

        Push-Task -Name "Build Tidy HTML5" -ScriptBlock {
            $CMakeArgs =
                "-G Ninja",
                "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
                "-DCMAKE_INSTALL_PREFIX=$TidyDependencyPath",
                "-DCMAKE_PDB_OUTPUT_DIRECTORY=$TidyDependencyPath\bin",
                "-DCMAKE_C_COMPILER=cl.exe",
                "-DCMAKE_CXX_COMPILER=cl.exe" -join " "

            Invoke-CMakeTasks -WorkingDir $TidyDependencyPath -CMakeArgs $CMakeArgs
        }

        Push-Task -Name "Setup LibEtPan Dependencies" -ScriptBlock {
            Copy-Item "$ProjectRoot\windows\vs\libetpan\libetpan.vcxproj" -Destination "$LibEtPanDependencyPath\build-windows\libetpan" -Force -ErrorAction Stop

            $ExternalsPath = "$LibEtPanDependencyPath\third-party"
            if (-Not (Test-Path "$ExternalsPath\include")) {
                New-Item -Path "$ExternalsPath\include" -ItemType Directory -ErrorAction Stop
            }
            
            if (-Not (Test-Path "$ExternalsPath\lib64")) {
                New-Item -Path "$ExternalsPath\lib64" -ItemType Directory -ErrorAction Stop
            }

            Copy-Item -Path "$ZlibDependencyPath\include" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop
            Copy-Item -Path "$ZlibDependencyPath\lib64" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop
            Copy-Item -Path "$SaslDependencyPath\include" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop
            Copy-Item -Path "$SaslDependencyPath\lib64" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop
            Copy-Item -Path "$OpenSslDependencyPath\include" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop
            Copy-Item -Path "$OpenSslDependencyPath\lib64" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop
        }

        Push-Task -Name "Build LibEtPan" -ScriptBlock {
            MSBuild "$LibEtPanDependencyPath\build-windows\libetpan.sln" /t:libetpan /p:Configuration="Release" /p:Platform="x64" /p:DebugSymbols=true /p:DebugType=pdbonl
        }

        Push-Task -Name "Build CTemplate" -ScriptBlock {
            Copy-Item -Path "$ProjectRoot\windows\vs\ctemplate\libctemplate.vcxproj" -Destination "$CTemplateDependencyPath\vsprojects\libctemplate" -Force -ErrorAction Stop | Write-Host
            MSBuild "$CTemplateDependencyPath\ctemplate.sln" /t:libctemplate /p:Configuration="Release" /p:Platform="x64" /p:DebugSymbols=true /p:DebugType=pdbonly
        }

        Push-Task -Name "Setup CMailcore Dependencies" -ScriptBlock {
            $ExternalsPath = "$ProjectRoot\Externals"
            if (-Not (Test-Path "$ExternalsPath\include")) {
                New-Item -Path "$ExternalsPath\include" -ItemType Directory -ErrorAction Stop
            }
            
            if (-Not (Test-Path "$ExternalsPath\lib64")) {
                New-Item -Path "$ExternalsPath\lib64" -ItemType Directory -ErrorAction Stop
            }

            Copy-Item -Path "$ZlibDependencyPath\include" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$ZlibDependencyPath\lib64" -Destination $ExternalsPath -Exclude "*.dll" -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$SaslDependencyPath\include" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$SaslDependencyPath\lib64" -Destination $ExternalsPath -Exclude "*.dll" -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$OpenSslDependencyPath\include" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$OpenSslDependencyPath\lib64" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$CTemplateDependencyPath\src\windows\include\ctemplate" -Destination "$ExternalsPath\include" -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$CTemplateDependencyPath\x64\Release\*" -Destination "$ExternalsPath\lib64" -Exclude "*.dll" -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$LibEtPanDependencyPath\build-windows\include" -Destination $ExternalsPath -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$LibEtPanDependencyPath\build-windows\x64\Release\*" -Destination "$ExternalsPath\lib64" -Exclude "*.dll" -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$TidyDependencyPath\include\*" -Destination "$ExternalsPath\include\tidy" -Recurse -Force -ErrorAction Stop -PassThru | Write-Host
            Copy-Item -Path "$TidyDependencyPath\lib\rdtidy.lib" -Destination "$ExternalsPath\lib64" -Force -ErrorAction Stop -PassThru | Write-Host

            Copy-Item -Path "$ProjectRoot\windows\vs\ctemplate\include\template_cache.h" -Destination "$ExternalsPath\include\ctemplate" -Force -ErrorAction Stop | Write-Host
            Copy-Item -Path "$ProjectRoot\windows\vs\ctemplate\include\template_string.h" -Destination "$ExternalsPath\include\ctemplate" -Force -ErrorAction Stop | Write-Host
        }

        if ($Install) {
            Push-Task -Name "Install CMailcore Dependencies" -ScriptBlock {
                Install-File "$OpenSslDependencyPath\bin\libssl-1_1-x64.dll" -Destination $BinDir
                Install-File "$OpenSslDependencyPath\bin\libssl-1_1-x64.pdb" -Destination $BinDir
                Install-File "$OpenSslDependencyPath\bin\libcrypto-1_1-x64.dll" -Destination $BinDir
                Install-File "$OpenSslDependencyPath\bin\libcrypto-1_1-x64.pdb" -Destination $BinDir

                Install-File "$CTemplateDependencyPath\x64\Release\libctemplate.dll" -Destination $BinDir
                Install-File "$CTemplateDependencyPath\x64\Release\libctemplate.pdb" -Destination $BinDir

                Install-File "$SaslDependencyPath\bin\sasl2.dll" -Destination $BinDir
                Install-File "$SaslDependencyPath\bin\sasl2.pdb" -Destination $BinDir

                Install-File "$PSScriptRoot\bin\msvcp120.dll" -Destination $BinDir
                Install-File "$PSScriptRoot\bin\msvcr120.dll" -Destination $BinDir

                Install-File "$IcuPath\bin\icuuc$IcuVersionMajor.dll" -Destination $BinDir
                Install-File "$IcuPath\bin\icuin$IcuVersionMajor.dll" -Destination $BinDir
                Install-File "$IcuPath\bin\icudt$IcuVersionMajor.dll" -Destination $BinDir

                $SwiftRuntimeBin = Split-Path (Get-Command dispatch.dll -ErrorAction Stop).Source
                Install-File "$SwiftRuntimeBin\dispatch.dll" -Destination $BinDir
                Install-File "$SwiftRuntimeBin\BlocksRuntime.dll" -Destination $BinDir

                Install-File "$ZlibDependencyPath\lib64\zlib.dll" -Destination $BinDir
                Install-File "$ZlibDependencyPath\lib64\zlib.pdb" -Destination $BinDir
                Install-File "$ZlibDependencyPath\include\zlib.h" -Destination $IncludeDir
                Install-File "$ZlibDependencyPath\include\zconf.h" -Destination $IncludeDir
                Install-File "$ZlibDependencyPath\lib64\zlib.lib" -Destination $LibDir

                Install-File "$TidyDependencyPath\bin\rdtidy.dll" -Destination $BinDir
                Install-File "$TidyDependencyPath\bin\rdtidy.pdb" -Destination $BinDir
                Install-File "$TidyDependencyPath\include\tidy.h" -Destination "$IncludeDir\tidy"
                Install-File "$TidyDependencyPath\include\tidybuffio.h" -Destination "$IncludeDir\tidy"
                Install-File "$TidyDependencyPath\include\tidyenum.h" -Destination "$IncludeDir\tidy"
                Install-File "$TidyDependencyPath\include\tidyplatform.h" -Destination "$IncludeDir\tidy"
                Install-File "$TidyDependencyPath\lib\rdtidy.lib" -Destination $LibDir
                
                Install-Directory "$LibEtPanDependencyPath\build-windows\include\libetpan" -Destination "$IncludeDir\libetpan"
                Install-File "$LibEtPanDependencyPath\build-windows\x64\Release\libetpan.dll" -Destination $BinDir
                Install-File "$LibEtPanDependencyPath\build-windows\x64\Release\libetpan.pdb" -Destination $BinDir
                Install-File "$LibEtPanDependencyPath\build-windows\x64\Release\libetpan.lib" -Destination $LibDir
            }
        }

        Push-Task -Name "Build mailcore2/CMailCore" -ScriptBlock {
            $CMakeArgs =
                "-G Ninja",
                $ProjectRoot,
                "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
                "-DCMAKE_INSTALL_PREFIX=$InstallPath",
                $(if ($Install) { "-DCMAKE_PDB_OUTPUT_DIRECTORY=$InstallPath\bin"} else { "" }),
                "-DCMAKE_C_COMPILER=clang-cl.exe",
                "-DCMAKE_CXX_COMPILER=clang-cl.exe",
                "-DLIBXML_INCLUDE_DIR=$LibXml2Path\include",
                "-DLIBXML_LIBRARY=$LibXml2Path\lib\x64\\libxml2s.lib",
                "-DICU4C_INCLUDE_DIR=$IcuPath\include",
                "-DICU4C_UC_LIBRARY=$IcuPath\lib\x64\icuuc$IcuVersionMajor.lib",
                "-DICU4C_IN_LIBRARY=$IcuPath\lib\x64\icuin$IcuVersionMajor.lib",
                "-DDISPATCH_INCLUDE_DIR=$SwiftSDKPath\usr\include",
                "-DDISPATCH_LIBRARY=$SwiftSDKPath\usr\lib\swift\windows\x86_64\dispatch.lib",
                "-DDISPATCH_BLOCKS_LIBRARY=$SwiftSDKPath\usr\lib\swift\windows\x86_64\BlocksRuntime.lib" -join " "

            Invoke-CMakeTasks -WorkingDir "$ProjectRoot\.build\mailcore2" -CMakeArgs $CMakeArgs -NoInstall:$(-not $Install)
        }

        if ($Install) {
            Push-Task -Name "Collect Git Revision Data" -ScriptBlock {
                New-Item -Path "$InstallPath\etc" -ItemType Directory -Force -ErrorAction Ignore | Out-Null
                # Written explicitly rather than with `>`: PowerShell 5.1 redirects as UTF-16
                # and 7 as UTF-8, and these files are read back by the publish step.
                @{
                    "ctemplate-git-rev"  = (& git -C "$CTemplateDependencyPath" rev-parse HEAD)
                    "libetpan-git-rev"   = (& git -C "$LibEtPanDependencyPath" rev-parse HEAD)
                    "tidy-html5-git-rev" = (& git -C "$TidyDependencyPath" rev-parse HEAD)
                    "mailcore2-git-rev"  = (& git -C "$ProjectRoot" rev-parse HEAD)
                }.GetEnumerator() | ForEach-Object {
                    [IO.File]::WriteAllText("$InstallPath\etc\$($_.Key)", "$($_.Value)`n", (New-Object Text.UTF8Encoding $false))
                }
            }
        }
    }
    finally {
        Push-Task -Name "Shutdown" -ScriptBlock {
            Pop-Location
        }
    }
}
