@ECHO OFF

rem -----------------------------------------------------------------
rem Ensure TLS 1.2 for NuGet restore and download NuGet.exe if missing
rem -----------------------------------------------------------------
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; if (-not (Test-Path '.\.nuget')) { New-Item -ItemType Directory -Path '.\.nuget' -Force }; if (-not (Test-Path '.\.nuget\NuGet.exe')) { Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile '.\.nuget\NuGet.exe' }; & '.\.nuget\NuGet.exe' restore EntityFramework.sln -PackagesDirectory '.\.nuget\packages'"

rem -----------------------------------------------------------------
rem Locate the latest Visual Studio MSBuild (64-bit)
rem Try vswhere first, then fall back to known VS 2022/2019 paths
rem -----------------------------------------------------------------
set "MSBUILD="

rem Try vswhere (x86 Program Files)
set "VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe 2^>nul`) do set "MSBUILD=%%i"
)

rem Fallback: known path for VS 2022+ (including Insiders)
if not defined MSBUILD (
    if exist "C:\Program Files\Microsoft Visual Studio\18\Insiders\MSBuild\Current\bin\MSBuild.exe" (
        set "MSBUILD=C:\Program Files\Microsoft Visual Studio\18\Insiders\MSBuild\Current\bin\MSBuild.exe"
    )
)
if not defined MSBUILD (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\bin\MSBuild.exe" (
        set "MSBUILD=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\bin\MSBuild.exe"
    )
)
if not defined MSBUILD (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\bin\MSBuild.exe" (
        set "MSBUILD=C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\bin\MSBuild.exe"
    )
)
if not defined MSBUILD (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\bin\MSBuild.exe" (
        set "MSBUILD=C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\bin\MSBuild.exe"
    )
)

if not defined MSBUILD (
    echo ERROR: Could not locate a modern MSBuild. Install Visual Studio 2019 or later.
    exit /b 1
)

echo Using MSBuild: %MSBUILD%

rem -----------------------------------------------------------------
rem Build the solution (Net40 skipped by default; use /p:IncludeNet40=true to opt in)
rem -----------------------------------------------------------------
"%MSBUILD%" "%~dp0EF.msbuild" /t:EnableSkipStrongNames /v:minimal /maxcpucount /nodeReuse:false /p:RestorePackages=false /p:DownloadNuGetExe=false /p:StyleCopEnabled=false /p:RunCodeAnalysis=false /p:BuildCoreOnly=true %*
