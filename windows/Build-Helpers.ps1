# Stand-ins for the internal RD build modules (RDBuildCMake, RDBuildMSVC, RDDependency), so
# that a plain clone of the public repository builds on a machine that only has the Swift
# toolchain and VS Build Tools.
#
# Common.ps1 dot-sources this file *after* importing the RD modules, so these definitions win
# even inside the CI image. That is deliberate for the toolchain functions: the RD versions
# pick their own MSVC and Swift, which would let the machine build with something other than
# what pins.json claims. Initialize-SDK and Invoke-BuildModuleTarget are not reimplemented
# here - the Swift build still needs the real modules for those.

# Every hardcoded Visual Studio path in this file goes through here.
$Script:MailcoreVsBuildTools = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"

# Build-Helpers.ps1 is dot-sourced by Common.ps1, but the toolchain functions are also reached
# through the RD-shadowing path before Common.ps1 finishes, so read the pins locally instead of
# calling back into it.
function Get-MailcorePinsForHelpers {
    $path = Join-Path $PSScriptRoot "pins.json"
    if (-not (Test-Path -LiteralPath $path)) { throw "Build pins not found: $path" }
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).toolchain
}

function Push-Task {
    param([string]$Name, [scriptblock]$ScriptBlock)
    Write-Host "`n== $Name ==" -ForegroundColor Cyan
    & $ScriptBlock
}

function Write-TaskLog {
    param([string]$Message)
    Write-Host $Message
}

function Test-Directory {
    param([string]$Path, [string]$SuccessMessage, [string]$FailMessage)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw $FailMessage
    }
    Write-Host $SuccessMessage
}

# Brings each dependency to the exact revision from pins.json. An existing checkout is
# re-pointed rather than trusted: the pins are part of the digest the prebuilt archive is named
# after, so a clone left behind at an older revision would produce a differently-named archive
# with the wrong contents inside it.
#
# The revision is an exact commit, which `git clone --branch` cannot take, so the fetch goes
# into an empty repository instead.
function Initialize-Dependencies {
    param([string]$Path, [array]$Dependencies)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    foreach ($dependency in $Dependencies) {
        $destination = Join-Path $Path $dependency.Directory

        if (-not (Test-Path -LiteralPath (Join-Path $destination ".git"))) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            git -C $destination init --quiet
            if ($LASTEXITCODE -ne 0) { throw "Failed to init $($dependency.Name)" }
            git -C $destination remote add origin $dependency.GitUrl
            if ($LASTEXITCODE -ne 0) { throw "Failed to add remote for $($dependency.Name)" }
        }

        $head = (& git -C $destination rev-parse --verify --quiet HEAD)
        if ($LASTEXITCODE -eq 0 -and $head -and $head.Trim() -eq $dependency.GitRevision) {
            Write-TaskLog "$($dependency.Name) already at $($dependency.GitRevision)"
            continue
        }

        Write-TaskLog "Checking out $($dependency.Name) at $($dependency.GitRevision)"
        git -C $destination fetch --depth 1 origin $dependency.GitRevision
        if ($LASTEXITCODE -ne 0) { throw "Failed to fetch $($dependency.Name) at $($dependency.GitRevision)" }
        # A dependency tree is a build directory too: previous artefacts must not survive a
        # revision change, or they get linked into the archive.
        git -C $destination checkout --quiet --force FETCH_HEAD
        if ($LASTEXITCODE -ne 0) { throw "Failed to check out $($dependency.Name) at $($dependency.GitRevision)" }
        git -C $destination clean -xdfq
        if ($LASTEXITCODE -ne 0) { throw "Failed to clean $($dependency.Name)" }
    }
}

# Points SDKROOT at the pinned Swift Windows SDK when the environment has not already set it.
# Named distinctly from the RD module's Initialize-SDK so it never shadows it.
function Initialize-MailcoreSdkRoot {
    if ($env:SDKROOT -and (Test-Path -LiteralPath $env:SDKROOT)) { return }
    $toolchain = Get-MailcorePinsForHelpers
    $platform = Join-Path $env:LOCALAPPDATA "Programs\Swift\Platforms\$($toolchain.swift)"
    $sdk = Join-Path $platform "Windows.platform\Developer\SDKs\Windows.sdk"
    if (-not (Test-Path -LiteralPath $sdk)) {
        throw "Swift $($toolchain.swift) Windows SDK not found at $sdk. Install it, or update windows\pins.json."
    }
    $env:SDKROOT = $sdk
    Write-TaskLog "SDKROOT was unset, using $env:SDKROOT"
}

function Invoke-VsDevCmd {
    param([string]$Version)
    $toolset = (Get-MailcorePinsForHelpers).msvcToolset
    $vsDevCmd = "$Script:MailcoreVsBuildTools\VC\Auxiliary\Build\vcvars64.bat"
    if (-not (Test-Path -LiteralPath $vsDevCmd)) { throw "vcvars64.bat not found at $vsDevCmd" }
    # -vcvars_ver takes the pinned toolset rather than a hardcoded one, so that changing
    # pins.json changes what actually compiles - not just what the digest claims.
    $environment = cmd.exe /d /c "`"$vsDevCmd`" -vcvars_ver=$toolset >nul && set"
    foreach ($line in $environment) {
        if ($line -match '^([^=]+)=(.*)$') {
            Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
        }
    }
}

# Puts exactly the pinned toolchain on PATH. Swift 5.10.1 ships clang 16, which the 14.40+ STL
# rejects (STL1000), hence a toolset pinned to 14.39 - but the point is general: whatever
# pins.json names is what runs, because the digest promises the binaries came from it.
function Initialize-Toolchain {
    $toolchain = Get-MailcorePinsForHelpers

    # Toolchain directories are named after the version with a flavour suffix, e.g.
    # "5.10.1+Asserts", so match on the prefix rather than requiring an exact directory name.
    $toolchainsRoot = Join-Path $env:LOCALAPPDATA "Programs\Swift\Toolchains"
    if (-not (Test-Path -LiteralPath $toolchainsRoot)) {
        throw "No Swift toolchains found at $toolchainsRoot"
    }
    $pinnedToolchain = Get-ChildItem -LiteralPath $toolchainsRoot -Directory |
        Where-Object { $_.Name -eq $toolchain.swift -or $_.Name -like "$($toolchain.swift)+*" } |
        Sort-Object Name |
        Select-Object -First 1
    if (-not $pinnedToolchain) {
        $available = (Get-ChildItem -LiteralPath $toolchainsRoot -Directory | ForEach-Object Name) -join ", "
        throw "Swift $($toolchain.swift) not found under $toolchainsRoot (present: $available). Install it, or update windows\pins.json."
    }
    $swiftBin = Get-ChildItem -LiteralPath $pinnedToolchain.FullName -Filter clang-cl.exe -Recurse -File |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if (-not $swiftBin) { throw "clang-cl.exe not found under $($pinnedToolchain.FullName)" }

    $msvcBin = "$Script:MailcoreVsBuildTools\VC\Tools\MSVC\$($toolchain.msvcToolset)\bin\Hostx64\x64"
    if (-not (Test-Path -LiteralPath $msvcBin)) { throw "MSVC toolset $($toolchain.msvcToolset) not found at $msvcBin" }
    $windowsSdkBin = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\$($toolchain.windowsSdk)\x64"
    if (-not (Test-Path -LiteralPath $windowsSdkBin)) { throw "Windows SDK $($toolchain.windowsSdk) not found at $windowsSdkBin" }

    $cmakeBin = "$Script:MailcoreVsBuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
    $ninjaBin = "$Script:MailcoreVsBuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
    $env:Path = "$swiftBin;$msvcBin;$windowsSdkBin;$cmakeBin;$ninjaBin;$env:Path"

    Write-TaskLog "Toolchain: Swift $($pinnedToolchain.Name), MSVC $($toolchain.msvcToolset), SDK $($toolchain.windowsSdk)"
}

function MSBuild {
    $msbuild = "$Script:MailcoreVsBuildTools\MSBuild\Current\Bin\MSBuild.exe"
    & $msbuild @args
    if ($LASTEXITCODE -ne 0) { throw "MSBuild failed with exit code $LASTEXITCODE" }
}

function ConvertTo-ArgumentList {
    param([string]$Arguments)
    return [regex]::Matches($Arguments, '(?:[^\s"]+|"[^"]*")+') | ForEach-Object {
        $_.Value.Trim('"')
    }
}

function Invoke-CMakeTasks {
    param([string]$WorkingDir, [string]$CMakeArgs, [switch]$NoInstall)
    $buildDir = Join-Path $WorkingDir ".rd-build"
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    $arguments = @(ConvertTo-ArgumentList $CMakeArgs)

    # RD's helper accepts an optional positional source directory. Convert it
    # to CMake's explicit -S form so it is not passed twice.
    $sourceDir = $WorkingDir
    $explicitSource = $arguments | Where-Object {
        $_ -notlike "-*" -and
        (Test-Path -LiteralPath (Join-Path $_ "CMakeLists.txt") -PathType Leaf)
    } | Select-Object -First 1
    if ($explicitSource) {
        $sourceDir = $explicitSource
        $arguments = @($arguments | Where-Object { $_ -ne $explicitSource })
    }

    # Swift's llvm-mt depends on libxml2 and fails when its installation path
    # contains non-ASCII characters. The Windows SDK manifest tool is native
    # to this toolchain and does not have that dependency.
    if (-not ($arguments | Where-Object { $_ -like "-DCMAKE_MT=*" })) {
        $windowsMt = (Get-Command mt.exe -ErrorAction Stop).Source
        $arguments += "-DCMAKE_MT=$windowsMt"
    }
    & cmake -S $sourceDir -B $buildDir @arguments
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed in $WorkingDir" }
    & cmake --build $buildDir --parallel
    if ($LASTEXITCODE -ne 0) { throw "CMake build failed in $WorkingDir" }
    if (-not $NoInstall) {
        & cmake --install $buildDir
        if ($LASTEXITCODE -ne 0) { throw "CMake install failed in $WorkingDir" }
    }
}

# Destination is always treated as a directory and created when missing.
function Install-File {
    param([string]$Path, [string]$Destination)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -LiteralPath $Path -Destination $Destination -Force -ErrorAction Stop
}

function Install-Directory {
    param([string]$Path, [string]$Destination)
    New-Item -ItemType Directory -Path (Split-Path $Destination) -Force | Out-Null
    Copy-Item -LiteralPath $Path -Destination $Destination -Recurse -Force -ErrorAction Stop
}
