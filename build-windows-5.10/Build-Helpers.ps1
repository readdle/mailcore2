# Minimal stand-ins for the internal RD build modules (RDBuildCMake, RDBuildMSVC,
# RDDependency). Dot-sourced by Build-Mailcore2.ps1 when those modules are not installed, so a
# plain clone of the public repository builds on a machine that only has the Swift toolchain and
# VS Build Tools. Inside the CI image the real modules are present and win.

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

# Shallow-clones each dependency once. A directory that already has .git is taken as ready: the
# remote and HEAD are not re-checked and an existing checkout is never updated - delete it to
# force a refetch.
function Initialize-Dependencies {
    param([string]$Path, [array]$Dependencies)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    foreach ($dependency in $Dependencies) {
        $destination = Join-Path $Path $dependency.Directory
        if (-not (Test-Path -LiteralPath (Join-Path $destination ".git"))) {
            $ref = if ($dependency.GitBranch) { $dependency.GitBranch } else { $dependency.GitRevision }
            git clone --branch $ref --depth 1 $dependency.GitUrl $destination
            if ($LASTEXITCODE -ne 0) { throw "Failed to clone $($dependency.Name)" }
        }
    }
}

function Invoke-VsDevCmd {
    param([string]$Version)
    $vsDevCmd = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    if (-not (Test-Path -LiteralPath $vsDevCmd)) { throw "vcvars64.bat not found" }
    $environment = cmd.exe /d /c "`"$vsDevCmd`" -vcvars_ver=14.39 >nul && set"
    foreach ($line in $environment) {
        if ($line -match '^([^=]+)=(.*)$') {
            Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
        }
    }
}

# Swift 5.10.1 ships clang 16, which the 14.40+ STL rejects (STL1000), hence the 14.39 toolset.
function Initialize-Toolchain {
    $swiftRoot = Join-Path $env:LOCALAPPDATA "Programs\Swift"
    $swiftBin = Get-ChildItem -LiteralPath (Join-Path $swiftRoot "Toolchains") -Filter clang-cl.exe -Recurse -File |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if (-not $swiftBin) { throw "Swift clang-cl.exe not found under $swiftRoot" }
    $msvcBin = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.39.33519\bin\Hostx64\x64"
    $windowsSdkBin = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64"
    $cmakeBin = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
    $ninjaBin = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
    $env:Path = "$swiftBin;$msvcBin;$windowsSdkBin;$cmakeBin;$ninjaBin;$env:Path"
}

function MSBuild {
    $msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
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
