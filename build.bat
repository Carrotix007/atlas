@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   ATLAS - Build
echo ============================================
echo.

:: ── Finde Visual Studio ──
set "VSDIR="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

:: Versuch 1: vswhere
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -property installationPath`) do set "VSDIR=%%i"
)

:: Versuch 2: D:\BuildTools (custom install)
if not defined VSDIR (
    if exist "D:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" (
        set "VSDIR=D:\BuildTools"
    )
)

:: Versuch 3: Standard C: Pfad
if not defined VSDIR (
    if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" (
        set "VSDIR=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
    )
)

if not defined VSDIR (
    echo [FEHLER] Visual Studio Build Tools nicht gefunden.
    echo          Fuehre zuerst setup.bat aus.
    pause
    exit /b 1
)

echo [1/6] VS Build Tools gefunden: %VSDIR%

:: ── Lade MSVC Umgebung ──
call "%VSDIR%\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
if %errorlevel% neq 0 (
    echo [FEHLER] vcvarsall.bat fehlgeschlagen.
    pause
    exit /b 1
)
echo [2/6] MSVC x64 Umgebung geladen.

:: ── Lade WebView2 SDK ──
set "DEPS_DIR=%~dp0deps"
set "WV2_DIR=%DEPS_DIR%\webview2"

if not exist "%WV2_DIR%\build\native\include\WebView2.h" (
    echo [3/6] Lade WebView2 SDK herunter...
    if not exist "%DEPS_DIR%" mkdir "%DEPS_DIR%"

    powershell -NoProfile -Command ^
        "$url = 'https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.2903.40'; " ^
        "$zip = '%DEPS_DIR%\webview2.zip'; " ^
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
        "Invoke-WebRequest -Uri $url -OutFile $zip; " ^
        "Expand-Archive -Path $zip -DestinationPath '%WV2_DIR%' -Force; " ^
        "Remove-Item $zip"

    if not exist "%WV2_DIR%\build\native\include\WebView2.h" (
        echo [FEHLER] WebView2 SDK Download fehlgeschlagen.
        pause
        exit /b 1
    )
) else (
    echo [3/6] WebView2 SDK bereits vorhanden.
)

:: ── Kompiliere ──
set "BUILD_DIR=%~dp0build"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

set "WV2_INC=%WV2_DIR%\build\native\include"
set "WV2_LIB=%WV2_DIR%\build\native\x64"

:: ── Generiere Icon ──
if not exist "%~dp0src\app.ico" (
    echo [4/6] Generiere Icon...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\gen-icon.ps1"
) else (
    echo [4/6] Icon bereits vorhanden.
)

:: ── Kompiliere Resource ──
if not exist "%~dp0src\app.ico" (
    echo [FEHLER] Icon wurde nicht erstellt.
    pause
    exit /b 1
)
echo [5/6] Kompiliere Resource...
pushd "%~dp0src"
rc.exe /nologo /fo resource.res resource.rc
popd

echo [6/6] Kompiliere DisplayHelper.exe...

cl.exe /nologo /EHsc /std:c++17 /O2 ^
    /I"%WV2_INC%" ^
    "%~dp0src\main.cpp" ^
    /Fe:"%BUILD_DIR%\DisplayHelper.exe" ^
    /link /SUBSYSTEM:WINDOWS ^
    /LIBPATH:"%WV2_LIB%" ^
    "%~dp0src\resource.res" ^
    WebView2LoaderStatic.lib ^
    user32.lib gdi32.lib ole32.lib oleaut32.lib advapi32.lib shell32.lib

if %errorlevel% neq 0 (
    echo.
    echo [FEHLER] Kompilierung fehlgeschlagen.
    pause
    exit /b 1
)

:: ── Kopiere HTML (versteckt) ──
attrib -h -s "%BUILD_DIR%\atlas-gui.html" >nul 2>&1
copy /y "%~dp0atlas-gui.html" "%BUILD_DIR%\atlas-gui.html"
attrib +h +s "%BUILD_DIR%\atlas-gui.html" >nul 2>&1

:: ── Kopiere Scripts (versteckt) ──
if not exist "%BUILD_DIR%\scripts" mkdir "%BUILD_DIR%\scripts"
attrib -h -s "%BUILD_DIR%\scripts" >nul 2>&1
attrib -h -s "%BUILD_DIR%\scripts\*.ps1" >nul 2>&1
copy /y "%~dp0scripts\*.ps1" "%BUILD_DIR%\scripts\" >nul
attrib +h +s "%BUILD_DIR%\scripts" >nul 2>&1
for %%f in ("%BUILD_DIR%\scripts\*.ps1") do attrib +h +s "%%f" >nul 2>&1

:: ── Aufraeumen ──
del /q "%~dp0src\main.obj" 2>nul
del /q "%~dp0src\resource.res" 2>nul

echo.
echo ============================================
echo   Build erfolgreich!
echo   Ausgabe: build\DisplayHelper.exe
echo   Starte mit: build\DisplayHelper.exe
echo ============================================
echo.

:: ── Direkt starten? ──
set /p START="Jetzt starten? (j/n): "
if /i "%START%"=="j" start "" "%BUILD_DIR%\DisplayHelper.exe"

pause
