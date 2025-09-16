@echo off
setlocal EnableExtensions
title CSWatch Auto — Install Prerequisites

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

:: Elevate (optional)
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

cls
echo ================================================================
echo Installing required software via install-deps.ps1
echo (Python, Node/NVM, OBS, PostgreSQL, VS Build Tools, etc.)
echo Repo root: %ROOT%
echo ================================================================
echo.

if not exist "%ROOT%install-deps.ps1" (
  echo [ERROR] install-deps.ps1 not found in repo root.
  goto :fail
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%install-deps.ps1"
if errorlevel 1 (
  echo.
  echo ============================= ERROR ===============================
  echo install-deps.ps1 reported an error. See output above.
  echo ===================================================================
  echo.
  goto :fail
)

echo.
echo Prerequisite installation completed successfully.
goto :ok

:fail
echo.
echo Press any key to close...
pause >nul
endlocal & exit /b 1

:ok
echo.
echo Press any key to close...
pause >nul
endlocal & exit /b 0
