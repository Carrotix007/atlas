@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   ATLAS - Release ZIP erstellen
echo ============================================
echo.

:: Zuerst build.bat ausfuehren
call "%~dp0build.bat"
if %errorlevel% neq 0 (
    echo [FEHLER] Build fehlgeschlagen. Release-ZIP nicht erstellt.
    pause
    exit /b 1
)

:: Unhide files damit sie im ZIP landen
attrib -h -s "%~dp0build\atlas-gui.html" >nul 2>&1
attrib -h -s "%~dp0build\scripts" >nul 2>&1
attrib -h -s "%~dp0build\scripts\*.ps1" >nul 2>&1

:: ZIP erstellen mit PowerShell
set "ZIP_NAME=%~dp0atlas-release.zip"
if exist "%ZIP_NAME%" del /q "%ZIP_NAME%"

powershell -NoProfile -Command ^
    "Compress-Archive -Path '%~dp0build\DisplayHelper.exe','%~dp0build\atlas-gui.html','%~dp0build\scripts' -DestinationPath '%ZIP_NAME%' -Force"

:: Files wieder hiden
attrib +h +s "%~dp0build\atlas-gui.html" >nul 2>&1
attrib +h +s "%~dp0build\scripts" >nul 2>&1
for %%f in ("%~dp0build\scripts\*.ps1") do attrib +h +s "%%f" >nul 2>&1

if not exist "%ZIP_NAME%" (
    echo [FEHLER] ZIP wurde nicht erstellt.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Release-ZIP erstellt: atlas-release.zip
echo   Naechste Schritte:
echo     1. GitHub Release erstellen
echo     2. atlas-release.zip als Asset hochladen
echo     3. User laedt install-atlas.ps1 aus
echo ============================================
echo.
pause
