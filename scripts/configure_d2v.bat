@echo off
setlocal EnableExtensions
:: configure_d2v.bat (lite) — run per-flavor setup.py without menus
:: Usage: configure_d2v.bat [/single | /multi | /both]

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


set "ARG=%~1"
if /I "%ARG%"==/single goto do_single
if /I "%ARG%"==/multi  goto do_multi
:: default -> both
:do_both
call "%~f0" /multi
call "%~f0" /single
goto :eof

:do_single
call :RUN_SETUP d2v_single
goto :eof

:do_multi
call :RUN_SETUP d2v_multi
goto :eof

:RUN_SETUP
set "FLAVOR=%~1"
set "FDIR=%ROOT%%FLAVOR%"
if not exist "%FDIR%\setup.py" (
  echo [%FLAVOR%] setup.py not found at %FDIR%\setup.py
  exit /b 0
)
:: python detector
set "PYEXE="
python --version >nul 2>&1 && set "PYEXE=python"
if not defined PYEXE if exist "%SystemRoot%\py.exe" "%SystemRoot%\py.exe" -3 --version >nul 2>&1 && set "PYEXE=%SystemRoot%\py.exe -3"
if not defined PYEXE (
  echo [ERROR] Python not found.
  exit /b 1
)
:: backup config.ini if present
set "CFG=%FDIR%\config.ini"
if exist "%CFG%" (
  for /f "tokens=1-4 delims=/- " %%a in ("%date%") do set "DT=%%d%%b%%c"
  for /f "tokens=1-3 delims=:." %%a in ("%time%") do set "TM=%%a%%b%%c"
  copy /Y "%CFG%" "%CFG%.%DT%_%TM%.bak" >nul 2>&1
  echo [%FLAVOR%] Backed up config.ini -> config.ini.%DT%_%TM%.bak
)
pushd "%FDIR%"
echo [%FLAVOR%] Running: %PYEXE% setup.py
call %PYEXE% setup.py
set "RC=%ERRORLEVEL%"
popd
echo [%FLAVOR%] setup.py exit code: %RC%
exit /b %RC%
