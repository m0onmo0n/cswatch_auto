@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: -------- robust repo root resolver (works from scripts\ or root)
set "ROOT=%~dp0"
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
if not "%ROOT:~-1%"=="\" set "ROOT=%ROOT%\"
for %%I in ("%ROOT%\..") do set "PARENT=%%~fI"
if defined PARENT if not "%PARENT:~-1%"=="\" set "PARENT=%PARENT%\"
if exist "%PARENT%d2v_multi"  set "ROOT=%PARENT%"
if exist "%PARENT%d2v_single" set "ROOT=%PARENT%"
if exist "%PARENT%csdm-fork"  set "ROOT=%PARENT%"
cd /d "%ROOT%"

echo [Runner] %~f0
echo [Runner] Repo root: %ROOT%
echo.

:: -------- interactive when no arg
if "%~1"=="" (
  :menu
  echo ==================================================
  echo              Demo2Video — Runner
  echo ==================================================
  echo   [M] D2V Multi (pipelined)
  echo   [S] D2V Single (classic)
  echo   [Q] Quit
  echo.
  choice /C MSQ /N /M "Select: "
  set "sel=%errorlevel%"
  if "%sel%"=="3" goto :done
  if "%sel%"=="1" ( set "MODE=multi" ) else if "%sel%"=="2" ( set "MODE=single" ) else ( cls & goto :menu )
  echo.
) else (
  set "MODE=%~1"
)

:: -------- mode setup
if /I "%MODE%"=="single" (
  set "APP_NAME=D2V Single"
  set "APP_DIR=%ROOT%d2v_single"
  set "MAIN=main.py"
  set "PORT=5000"
) else if /I "%MODE%"=="multi" (
  set "APP_NAME=D2V Multi"
  set "APP_DIR=%ROOT%d2v_multi"
  set "MAIN=main.py"
  set "PORT=5001"
) else (
  echo Usage: scripts\run.bat ^<single^|multi^>
  goto :done
)

if not exist "%APP_DIR%\%MAIN%" (
  echo [ERROR] %APP_NAME% entrypoint not found: "%APP_DIR%\%MAIN%"
  goto :done
)

:: -------- pick Python
set "PYEXE=python"
where python >nul 2>&1 || set "PYEXE=%SystemRoot%\py.exe -3"
for /f "delims=" %%V in ('%PYEXE% --version 2^>^&1') do set "PYV=%%V"
echo [Runner] Using: %PYEXE%  (%PYV%)
echo.

:: -------- (multi only) sanitize settings.txt safely via temp .ps1
if /I "%MODE%"=="multi" if exist "%ROOT%d2v_multi\settings.txt" (
  set "PSFILE=%TEMP%\sanitize_%RANDOM%.ps1"
  >  "%PSFILE%" echo $p = '%ROOT%d2v_multi\settings.txt'
  >> "%PSFILE%" echo if (Test-Path -LiteralPath $p^) {
  >> "%PSFILE%" echo   $t = Get-Content -LiteralPath $p
  >> "%PSFILE%" echo   $out = @()
  >> "%PSFILE%" echo   foreach ($line in $t^) {
  >> "%PSFILE%" echo     if ($line -match '^\s*#' -or $line -notmatch '='^) { $out += $line; continue }
  >> "%PSFILE%" echo     $kv = $line.Split('=',2)
  >> "%PSFILE%" echo     $k = $kv[0]
  >> "%PSFILE%" echo     $v = $kv[1].Trim()
  >> "%PSFILE%" echo     if ($v.Length -ge 2 -and $v[0] -eq '"' -and $v[$v.Length-1] -eq '"'^) { $v = $v.Substring(1, $v.Length-2) }
  >> "%PSFILE%" echo     $out += "$k=$v"
  >> "%PSFILE%" echo   }
  >> "%PSFILE%" echo   Set-Content -LiteralPath $p -Value $out -Encoding utf8
  >> "%PSFILE%" echo }
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" >nul 2>&1
  del /q "%PSFILE%" >nul 2>&1
)

:: -------- Start CSDM dev server (if present)
if exist "%ROOT%csdm-fork\scripts\develop-cli.mjs" (
  echo [1/3] Starting CSDM dev server...
  start "CSDM Dev Server" /D "%ROOT%csdm-fork" cmd /k node scripts\develop-cli.mjs
) else (
  echo [1/3] CSDM dev server not found; skipping.
)
echo.

:: -------- Start the Python app from its OWN folder
echo [2/3] Starting %APP_NAME%...
start "%APP_NAME% - python %MAIN%" /D "%APP_DIR%" cmd /k call %PYEXE% "%MAIN%"
echo.

:: -------- OBS (portable or configured)
set "OBS_CFG=%ROOT%obs_path.txt"
set "OBS_EXE="
if exist "%OBS_CFG%" for /f "usebackq delims=" %%P in ("%OBS_CFG%") do set "OBS_EXE=%%P"
if not defined OBS_EXE for %%D in ("%ROOT%Obs\bin\64bit\obs64.exe" "%ROOT%obs\bin\64bit\obs64.exe") do (
  if not defined OBS_EXE if exist "%%~fD" set "OBS_EXE=%%~fD"
)
if defined OBS_EXE if exist "%OBS_EXE%" (
  for %%D in ("%OBS_EXE%") do set "OBS_DIR=%%~dpD"
  echo [3/3] Starting OBS Studio...
  start "OBS Studio" /D "%OBS_DIR%" "%OBS_EXE%"
) else (
  echo [3/3] OBS not started (path not configured).
)

:: -------- Open the web UI
echo.
echo [Runner] Opening http://localhost:%PORT% (after short delay)...
timeout /t 8 /nobreak >nul
start "" "http://localhost:%PORT%"

echo.
echo [Runner] Done launching. This window will remain open for diagnostics.
echo Press any key to close...
pause >nul

:done
endlocal
exit /b 0
