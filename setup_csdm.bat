@echo off
setlocal EnableExtensions
title Demo2Video — CSDM Setup Wizard

:: ---------------------------------------------------------------
:: Resolve repo root
:: ---------------------------------------------------------------
set "ROOT=%~dp0"
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
if not "%ROOT:~-1%"=="\" set "ROOT=%ROOT%\"

set "CSDM_DIR=csdm-fork"
set "CSDM_SETUP=setup_csdm.py"

:: ---------------------------------------------------------------
:: Elevate if not admin
:: ---------------------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)


:: ==================================================================
:: MAIN MENU  (tight loop; submenus are CALLed and return)
:: ==================================================================
:MAIN_LOOP
cls
call :CHECK_CSDM_BUILD_STATUS
echo ============ CSDM Status ============
if "%HAS_PKG%"=="1"  (echo  • package.json  : FOUND) else (echo  • package.json  : not found)
if "%HAS_NMOD%"=="1" (echo  • node_modules  : FOUND) else (echo  • node_modules  : not found)
if "%HAS_NATIVE%"=="1"(echo  • native build  : FOUND) else (echo  • native build  : not found)
echo -------------------------------------
if not "%HAS_PKG%"=="1" (
  echo %CSDM_DIR%\package.json not found. Clone it and return.
  echo.
  pause
  exit /b 0
)

echo ================================================================
echo Demo2Video — Setup Wizard
echo ================================================================
echo   [1] Install csdm 
echo   [2] Config setup (CSDM settings)
echo   [3] Nuke CSDM
echo   [4] Check prerequisites
echo   [Q] Quit
echo ------------------------------------------------
set "SEL="
set /p "SEL=Select [1/2/3/4/Q]: "
if not defined SEL goto :MAIN_LOOP
set "SEL=%SEL:~0,1%"

if /I "%SEL%"=="Q" goto :END_OK

if "%SEL%"=="1" (call :CSDM_INSTALL  ) & goto :MAIN_LOOP
if "%SEL%"=="2" (call :MENU_CONFIG   ) & goto :MAIN_LOOP
if "%SEL%"=="3" (call :NUKE_CSDM_MENU ) & goto :MAIN_LOOP
if "%SEL%"=="4" (call :MENU_PREREQS  ) & goto :MAIN_LOOP

:: anything else → redraw
goto :MAIN_LOOP

:: ==================================================================
:: Nuclear Option
:: ==================================================================
:NUKE_CSDM_MENU
cls
echo ============ Config Setup ============
echo   [1] Nuke CSDM
echo   [Q] Back
choice /C 1 /N /M "Select: "
set "S=%errorlevel%"
if "%S%"=="2" goto :MAIN_LOOP

if "%S%"=="1" ( call :SADGE )
echo Invalid selection.
pause >nul
exit /b 0

:NUKE_CSDM
start "Nuclear option" cmd /c "cd %ROOT%scripts\ && .\nuclear.bat"
pause >nul
goto :MAIN_LOOP

:: ==================================================================
:: csdm install setup
:: ==================================================================
:CSDM_INSTALL
cls
call :CHECK_CSDM_BUILD_STATUS
echo ============ CSDM Status ============
if "%HAS_PKG%"=="1"  (echo  • package.json  : FOUND) else (echo  • package.json  : not found)
if "%HAS_NMOD%"=="1" (echo  • node_modules  : FOUND) else (echo  • node_modules  : not found)
if "%HAS_NATIVE%"=="1"(echo  • native build  : FOUND) else (echo  • native build  : not found)
echo -------------------------------------
if not "%HAS_PKG%"=="1" (
  echo %CSDM_DIR%\package.json not found. Clone it and return.
  echo.
  pause
  exit /b 0
)
echo Installing CS Demo Manager dependencies...
pushd "%ROOT%\csdm-fork"

set "GYP_MSVS_VERSION=2022"
call npm config set engine-strict false --location=project >nul
call npm config set fund false --location=project >nul
call npm config set audit false --location=project >nul

echo Running: npm install (this may take a while)...
call npm install
set "NPM_RC=%ERRORLEVEL%"
echo npm install exit code: %NPM_RC%
echo.
goto :MAIN_LOOP


:: ==================================================================
:: Config setup
:: ==================================================================
:MENU_CONFIG
cls
echo ============ Config Setup ============
echo   [C] CSDM settings (settings.json + .env)
echo   [Q] Back
choice /C C /N /M "Select: "
set "S=%errorlevel%"
if "%S%"=="2" exit /b 0

if "%S%"=="1" ( call :RUNNER_CSDM_SETTINGS & exit /b )
echo Invalid selection.
pause >nul
exit /b 0

:RUNNER_CSDM_SETTINGS
if not exist "%ROOT%%CSDM_SETUP%" ( echo [INFO] %CSDM_SETUP% not found at repo root. & pause & exit /b 0 )
call :DETECT_PY
if errorlevel 1 ( echo [ERROR] Python not found. & pause & exit /b 1 )
set "RUNNER=%TEMP%\csdm_settings_%RANDOM%.bat"
(
  echo @echo off
  echo setlocal EnableExtensions
  echo title CSDM Settings
  echo cd /d "%ROOT%"
  echo echo ================ CSDM Settings ================
  echo call %PYEXE% "%CSDM_SETUP%"
  echo set "RC=%%ERRORLEVEL%%"
  echo echo.
  echo echo Finished with exit code %%RC%%.
  echo echo Press any key to close this window...
  echo pause ^>nul
  echo endlocal ^& exit /b %%RC%%
) > "%RUNNER%"
start "CSDM Settings" /WAIT "%ComSpec%" /c call "%RUNNER%"
set "RC=%ERRORLEVEL%"
del /q "%RUNNER%" >nul 2>&1
exit /b %RC%


:CHECK_CSDM_BUILD_STATUS
set "PKG=%ROOT%%CSDM_DIR%\package.json"
set "NMOD=%ROOT%%CSDM_DIR%\node_modules"
set "NATIVE=%ROOT%%CSDM_DIR%\src\node\os\get-running-process-exit-code\build"
set "HAS_PKG=0"
set "HAS_NMOD=0"
set "HAS_NATIVE=0"
if exist "%PKG%"    set "HAS_PKG=1"
if exist "%NMOD%"   set "HAS_NMOD=1"
if exist "%NATIVE%" set "HAS_NATIVE=1"
exit /b 0


:DETECT_PY
set "PYEXE=python"
where python >nul 2>&1 || set "PYEXE=%SystemRoot%\py.exe -3"
exit /b 0


:END_OK
echo.
echo Goodbye!
endlocal
exit /b 0

:SADGE
cls
echo =============== Nuclear Option ===============
echo  unfortunately this function isn't functioning :(
echo  please check github if there's an update, if you
echo  need help/has botched your csdm install; either try
echo  to reclone and try again or contact me on discord
echo                 @m0on_mo0n
echo =============== Nuclear Option ===============
echo .
pause
goto :NUKE_CSDM_MENU
