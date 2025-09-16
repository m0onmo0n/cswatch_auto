@echo off
setlocal EnableExtensions
title D2V Multi — YouTube Auth

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
set "SCRIPT_NAME=setup_youtube_auth.py"

:: sanity checks
if not exist "%APPDIR%" (
  echo [ERROR] Folder not found: %APPDIR%
  endlocal & exit /b 1
)
if not exist "%APPDIR%\%SCRIPT_NAME%" (
  echo [ERROR] %SCRIPT_NAME% not found at "%APPDIR%\%SCRIPT_NAME%"
  endlocal & exit /b 1
)

:: pick a Python
set "PYEXE=python"
where python >nul 2>&1 || set "PYEXE=%SystemRoot%\py.exe -3"

echo ================================================================
echo Launching YouTube OAuth for d2v_multi...
echo ================================================================
pushd "%APPDIR%"
call %PYEXE% "%SCRIPT_NAME%"
set "RC=%ERRORLEVEL%"
popd

if not "%RC%"=="0" (
  echo [ERROR] YouTube auth script exited with code %RC%.
  endlocal & exit /b %RC%
)

echo YouTube auth complete.
endlocal & exit /b 0
