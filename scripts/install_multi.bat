@echo off
setlocal EnableExtensions
title Demo2video Multi Processor

:: ---- repo-root resolver (works from scripts\ or root) ----
set "HERE=%~dp0"
for %%I in ("%HERE%") do set "HERE=%%~fI\"

set "ROOT=%HERE%"
:: If this BAT is inside ...\scripts\, bump ROOT to parent
for %%I in ("%ROOT%") do if /I "%%~nxI"=="scripts" (
  for %%P in ("%%~dpI\..") do set "ROOT=%%~fP\"
)

:: Safety net: if flavor folders are missing, bump once more
if not exist "%ROOT%d2v_single" if not exist "%ROOT%d2v_multi" (
  for %%P in ("%ROOT%\..") do set "ROOT=%%~fP\"
)

cd /d "%ROOT%"


set "APPDIR=%ROOT%d2v_multi"
if not exist "%APPDIR%\requirements.txt" (
  echo [ERROR] requirements.txt not found at "%APPDIR%\requirements.txt"
  endlocal & exit /b 1
)

where nvm >nul 2>&1 && (call nvm use lts >nul 2>&1)

set "PYEXE=python"
where python >nul 2>&1 || set "PYEXE=%SystemRoot%\py.exe -3"

echo ================================================================
echo Installing Demo2video Multi Processor...
echo ================================================================
pushd "%APPDIR%"
call %PYEXE% -m pip install -r requirements.txt
set "RC=%ERRORLEVEL%"
popd

if not "%RC%"=="0" (
  echo [ERROR] pip failed with exit code %RC%.
  endlocal & exit /b %RC%
)

echo Done.
endlocal & exit /b 0
