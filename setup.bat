@echo off
echo ============================================
echo   ATLAS - Entwicklungsumgebung Setup
echo ============================================
echo.

echo [1/2] Installiere Visual Studio 2022 Build Tools...
echo      (C++ Compiler + Windows SDK)
echo.
winget install Microsoft.VisualStudio.2022.BuildTools --override "--installPath D:\BuildTools --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --wait" --accept-package-agreements --accept-source-agreements

echo.
echo [2/2] Pruefe WebView2 Runtime...
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BEB-235B8DE587E7}" >nul 2>&1
if %errorlevel%==0 (
    echo      WebView2 Runtime ist bereits installiert.
) else (
    echo      Installiere WebView2 Runtime...
    winget install Microsoft.EdgeWebView2Runtime --accept-package-agreements --accept-source-agreements
)

echo.
echo ============================================
echo   Setup abgeschlossen!
echo   Fuehre jetzt build.bat aus.
echo ============================================
pause
