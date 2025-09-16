@echo off
setlocal EnableExtensions EnableDelayedExpansion

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



:: ------------------------------------------------------------------
:: Keep window open when double-clicked (spawn child in REPO ROOT)
:: ------------------------------------------------------------------
if /I not "%~1"=="from_shell" (
  start "Demo2Video — Single Launcher" /D "%ROOT%" cmd /k "%~f0" from_shell
  exit /b
)

cls
echo ================================================================
echo == Demo2Video single processor - Application Launcher
echo ================================================================
echo.

cd /d "%ROOT%"

:: sanity check
if not exist "%ROOT%d2v_single" (
  echo [ERROR] 'd2v_single' not found at: "%ROOT%d2v_single"
  echo Put this .bat in repo root or scripts\ with the resolver header.
  goto :DONE
)

:: pick Python
set "PYEXE=python"
where python >nul 2>&1 || set "PYEXE=%SystemRoot%\py.exe -3"

echo This will start all components.
echo Make sure you ran installs and YouTube auth first.
echo.

:: ---------------------------------------------------------------
:: OBS path (obs_path.txt in repo root)
:: ---------------------------------------------------------------
set "OBS_CFG=%ROOT%obs_path.txt"
set "OBS_EXE="

:: 1) honor saved path if valid
if exist "%OBS_CFG%" for /f "usebackq delims=" %%P in ("%OBS_CFG%") do set "OBS_EXE=%%P"
if defined OBS_EXE if exist "%OBS_EXE%" goto OBS_READY

:: 2) try portable defaults (Obs\... or obs\...)
for %%D in ("%ROOT%Obs\bin\64bit\obs64.exe" "%ROOT%obs\bin\64bit\obs64.exe") do (
  if not defined OBS_EXE if exist "%%~fD" set "OBS_EXE=%%~fD"
)
if defined OBS_EXE (
  >"%OBS_CFG%" echo %OBS_EXE%
  echo Detected OBS: %OBS_EXE%
  goto OBS_READY
)

:: 3) prompt user once
echo OBS not found in portable folder.
echo If you want this launcher to start OBS, enter full path to obs64.exe
echo Example: C:\Program Files\obs-studio\bin\64bit\obs64.exe
set /p "OBS_EXE=Path to obs64.exe (leave blank to skip): "
if defined OBS_EXE if exist "%OBS_EXE%" (
  >"%OBS_CFG%" echo %OBS_EXE%
  echo Saved OBS path.
) else (
  set "OBS_EXE="
  echo Skipping OBS auto-start.
)
:OBS_READY
echo.


:: optional: ensure Node LTS if NVM is present
where nvm >nul 2>&1 && (call nvm use lts >nul 2>&1)

:: ---------------------------------------------------------------
:: [1/4] Start CSDM dev server
:: ---------------------------------------------------------------
echo [1/4] Starting the CS Demo Manager dev server...
if exist "%ROOT%csdm-fork\scripts\develop-cli.mjs" (
  start "CSDM Dev Server" /D "%ROOT%csdm-fork" cmd /k node scripts\develop-cli.mjs
  echo   Launched: CSDM Dev Server
) else (
  echo   [WARN] csdm-fork\scripts\develop-cli.mjs not found; skipping dev server.
)
echo.

:: ---------------------------------------------------------------
:: [2/4] Start Single processor
:: ---------------------------------------------------------------
echo [2/4] Starting the multi processor...
start "D2V Single" /D "%ROOT%d2v_single" cmd /k call %PYEXE% main.py
echo   Launched: D2V Multi
echo.

:: ---------------------------------------------------------------
:: [3/4] Start OBS (if configured)
:: ---------------------------------------------------------------
if defined OBS_EXE if exist "%OBS_EXE%" (
  for %%D in ("%OBS_EXE%") do set "OBS_DIR=%%~dpD"
  echo [3/4] Starting OBS Studio...
  start "OBS Studio" /D "%OBS_DIR%" "%OBS_EXE%"
  echo   Launched: OBS Studio
) else (
  echo [3/4] OBS not started by launcher.
)
echo.

:: ---------------------------------------------------------------
:: [4/4] Open the web UI
:: ---------------------------------------------------------------
set "PORT=5001"
echo [4/4] Waiting 10 seconds for the web server to start...
timeout /t 10 /nobreak >nul
echo Opening http://localhost:%PORT%
start "" "http://localhost:%PORT%"
echo.

echo ================================================================
echo == Launcher finished. This window will remain open.
echo ================================================================
echo.
:DONE
endlocal
exit /b 0
