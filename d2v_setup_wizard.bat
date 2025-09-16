@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Demo2Video — Setup Wizard

:: ==================================================================
:: Paths & names
:: ==================================================================
set "ROOT=%~dp0"
cd /d "%ROOT%"
set "SCRIPTS=%ROOT%scripts\"
set "FLAVOR_DIR_SINGLE=d2v_single"
set "FLAVOR_DIR_MULTI=d2v_multi"
set "CSDM_DIR=csdm-fork"

:: helper filenames (wizard will search scripts\ then root)
set "INSTALL_SINGLE=install_single.bat"
set "INSTALL_MULTI=install_multi.bat"
set "AUTH_SINGLE=youtube_auth_single.bat"
set "AUTH_MULTI=youtube_auth_multi.bat"
set "INSTALL_DEPS_BAT=install_dependencies.bat"
set "CSDM_SETUP=setup_csdm.py"

:: ==================================================================
:: Elevate if not admin
:: ==================================================================
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
echo ================================================================
echo Demo2Video — Setup Wizard
echo ================================================================
echo   [1] Install D2V (Single / Multi / Both)
echo   [2] Config setup (Single / Multi / Both / CSDM settings)
echo   [3] Install / Repair CSDM
echo   [4] Check prerequisites
echo   [Q] Quit
echo ------------------------------------------------
set "SEL="
set /p "SEL=Select [1/2/3/4/Q]: "
if not defined SEL goto :MAIN_LOOP
set "SEL=%SEL:~0,1%"

if /I "%SEL%"=="Q" goto :END_OK

if "%SEL%"=="1" (call :MENU_INSTALL  ) & goto :MAIN_LOOP
if "%SEL%"=="2" (call :MENU_CONFIG   ) & goto :MAIN_LOOP
if "%SEL%"=="3" (call :MENU_CSDM     ) & goto :MAIN_LOOP
if "%SEL%"=="4" (call :MENU_PREREQS  ) & goto :MAIN_LOOP

:: anything else → redraw
goto :MAIN_LOOP



:: ==================================================================
:: Install D2V
:: ==================================================================
:MENU_INSTALL
cls
echo ============ Install D2V ============
echo   [S] D2V Single
echo   [M] D2V Multi
echo   [B] Both (Multi then Single)
echo   [Q] Back
choice /C SMBQ /N /M "Select: "
set "S=%errorlevel%"
if "%S%"=="4" exit /b 0

if "%S%"=="1" (
  call :FIND_SCRIPT "%INSTALL_SINGLE%" & call :RUNNER_WIN "Install d2v_single" "!FOUND!" "%ROOT%"
  exit /b
)
if "%S%"=="2" (
  call :FIND_SCRIPT "%INSTALL_MULTI%" & call :RUNNER_WIN "Install d2v_multi" "!FOUND!" "%ROOT%"
  exit /b
)
if "%S%"=="3" (
  call :FIND_SCRIPT "%INSTALL_MULTI%"  & call :RUNNER_WIN "Install d2v_multi"  "!FOUND!" "%ROOT%"
  call :FIND_SCRIPT "%INSTALL_SINGLE%" & call :RUNNER_WIN "Install d2v_single" "!FOUND!" "%ROOT%"
  exit /b
)
echo Invalid selection.
pause >nul
exit /b 0

:: ==================================================================
:: Config setup
:: ==================================================================
:MENU_CONFIG
cls
echo ============ Config Setup ============
echo   [S] Setup d2v_single (setup.py)
echo   [M] Setup d2v_multi  (setup.py)
echo   [B] Setup both (Multi then Single)
echo   [C] CSDM settings (settings.json + .env)
echo   [Q] Back
choice /C SMBQC /N /M "Select: "
set "S=%errorlevel%"
if "%S%"=="4" exit /b 0

if "%S%"=="1" ( call :RUNNER_SETUP "Setup d2v_single" "%ROOT%%FLAVOR_DIR_SINGLE%" & exit /b )
if "%S%"=="2" ( call :RUNNER_SETUP "Setup d2v_multi"  "%ROOT%%FLAVOR_DIR_MULTI%"  & exit /b )
if "%S%"=="3" (
  call :RUNNER_SETUP "Setup d2v_multi"  "%ROOT%%FLAVOR_DIR_MULTI%"
  call :RUNNER_SETUP "Setup d2v_single" "%ROOT%%FLAVOR_DIR_SINGLE%"
  exit /b
)
if "%S%"=="5" ( call :RUNNER_CSDM_SETTINGS & exit /b )
echo Invalid selection.
pause >nul
exit /b 0

:: ==================================================================
:: CSDM install/repair
:: ==================================================================
:MENU_CSDM
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

if not "%HAS_NMOD%"=="1" (
  echo node_modules missing — recommended: [I] Install
  set "PROMPT=Install now [I] / Clean rebuild [C] / Back [Q]: "
  set "MODE=install"
) else if not "%HAS_NATIVE%"=="1" (
  echo native build missing — recommended: [I] Install
  set "PROMPT=Install now [I] / Clean rebuild [C] / Back [Q]: "
  set "MODE=install"
) else (
  echo Everything looks built — you can Reinstall or Clean rebuild.
  set "PROMPT=Reinstall [R] / Clean rebuild [C] / Back [Q]: "
  set "MODE=rebuild"
)

choice /C IRCQ /N /M "%PROMPT%"
set "C=%errorlevel%"
if "%C%"=="4" exit /b 0

if "%MODE%"=="install" (
  if "%C%"=="1" ( call :RUNNER_CSDM_BUILD install & exit /b )
  if "%C%"=="2" ( call :RUNNER_CSDM_BUILD clean   & exit /b )
  if "%C%"=="3" ( call :RUNNER_CSDM_BUILD rebuild & exit /b )
) else (
  if "%C%"=="1" ( call :RUNNER_CSDM_BUILD rebuild & exit /b )
  if "%C%"=="2" ( call :RUNNER_CSDM_BUILD clean   & exit /b )
  if "%C%"=="3" ( exit /b 0 )
)
echo Invalid selection.
pause >nul
exit /b 0

:: ==================================================================
:: Prereqs
:: ==================================================================
:MENU_PREREQS
:: --------------------------------------------------------------
:: Prerequisites checker (installer is safe to re-run)
:: --------------------------------------------------------------
setlocal EnableExtensions EnableDelayedExpansion

:PREREQS_LOOP
cls
echo ============ Prerequisites ============
echo Repo root: %ROOT%
echo.

:: ---------- Detect Python ----------
set "PY_SUMMARY="
where python >nul 2>&1 && for /f "delims=" %%V in ('python --version 2^>^&1') do set "PY_SUMMARY=python %%V"
if not defined PY_SUMMARY if exist "%SystemRoot%\py.exe" (
  for /f "delims=" %%V in ('"%SystemRoot%\py.exe" -3 --version 2^>^&1') do set "PY_SUMMARY=py.exe %%V"
)
if defined PY_SUMMARY (echo Python : !PY_SUMMARY!) else (echo Python : NOT FOUND)

:: ---------- Detect Node ----------
set "NODE_SUMMARY="
where node >nul 2>&1 && for /f "delims=" %%V in ('node -v 2^>^&1') do set "NODE_SUMMARY=%%V"
if defined NODE_SUMMARY (echo Node   : !NODE_SUMMARY!) else (echo Node   : NOT FOUND)

:: ---------- Detect NVM ----------
set "NVM_SUMMARY="
where nvm >nul 2>&1 && for /f "delims=" %%V in ('nvm version 2^>^&1') do set "NVM_SUMMARY=%%V"
if defined NVM_SUMMARY (echo NVM    : !NVM_SUMMARY!) else (echo NVM    : NOT FOUND)

echo ---------------------------------------

:: ---------- Locate installer via common finder ----------
set "DEPS_BAT="
call :FIND_SCRIPT "%INSTALL_DEPS_BAT%"
set "DEPS_BAT=!FOUND!"
set "DEPS_DIR="
if defined DEPS_BAT for %%D in ("!DEPS_BAT!") do set "DEPS_DIR=%%~dpD"

if defined DEPS_BAT (
  set "HAS_INSTALLER=1"
  echo Installer: !DEPS_BAT!
) else (
  set "HAS_INSTALLER=0"
  echo Installer: NOT FOUND
  echo   looked for: %SCRIPTS%%INSTALL_DEPS_BAT%
  echo               %ROOT%%INSTALL_DEPS_BAT%
)

echo.
if "%HAS_INSTALLER%"=="1" (
  echo   [I] Run installer (safe to re-run)
) else (
  echo   [I] Installer not found - disabled
)
echo   [R] Re-check versions
echo   [Q] Back to main menu

set "C="
set /p "C=Select [I/R/Q]: "
if not defined C goto :PREREQS_LOOP
set "C=%C:~0,1%"

if /I "%C%"=="Q" ( endlocal & goto :eof )
if /I "%C%"=="R" goto :PREREQS_LOOP
if /I "%C%"=="I" (
  if not "%HAS_INSTALLER%"=="1" (
    echo.
    echo > Installer not found. Put it in scripts\ or repo root.
    echo.
    pause
    goto :PREREQS_LOOP
  )
  echo.
  echo Launching installer in a new window...
  echo (Close that window when it finishes; we will re-check.)
  start "Install prerequisites" /D "!DEPS_DIR!" /WAIT "%ComSpec%" /k call "!DEPS_BAT!"
  echo.
  echo Press any key to re-check...
  pause >nul
  goto :PREREQS_LOOP
)

:: Safety fallback
goto :PREREQS_LOOP

:: ==================================================================
:: Helpers: find, runners, status
:: ==================================================================
:FIND_SCRIPT
:: in: %1 = filename
:: out: FOUND = full path or empty
set "FOUND="
if exist "%SCRIPTS%%~1" set "FOUND=%SCRIPTS%%~1"
if not defined FOUND if exist "%ROOT%%~1" set "FOUND=%ROOT%%~1"
if not defined FOUND echo [ERROR] Missing script: %~1
exit /b 0

:RUNNER_WIN
:: args: Title, FullPathToBat, WorkDir
set "WTITLE=%~1"
set "FULLBAT=%~2"
set "WORKDIR=%~3"
if not exist "%FULLBAT%" ( echo [ERROR] Not found: %FULLBAT% & pause & exit /b 1 )
if not exist "%WORKDIR%" set "WORKDIR=%ROOT%"

set "RUNNER=%TEMP%\runner_%RANDOM%.bat"
(
  echo @echo off
  echo setlocal EnableExtensions
  echo title %WTITLE%
  echo cd /d "%WORKDIR%"
  echo echo ================= %WTITLE% =================
  echo call "%FULLBAT%"
  echo set "RC=%%ERRORLEVEL%%"
  echo echo.
  echo echo Finished with exit code %%RC%%.
  echo echo Press any key to close this window...
  echo pause ^>nul
  echo endlocal ^& exit /b %%RC%%
) > "%RUNNER%"
start "%WTITLE%" /WAIT "%ComSpec%" /c call "%RUNNER%"
set "RC=%ERRORLEVEL%"
del /q "%RUNNER%" >nul 2>&1
exit /b %RC%

:RUNNER_SETUP
:: args: Title, ProjectDir (has setup.py)
set "WTITLE=%~1"
set "PDIR=%~2"
if not exist "%PDIR%\setup.py" ( echo [INFO] setup.py not found at: %PDIR%\setup.py & pause & exit /b 0 )
call :DETECT_PY
if errorlevel 1 ( echo [ERROR] Python not found. & pause & exit /b 1 )

set "RUNNER=%TEMP%\setup_%RANDOM%.bat"
(
  echo @echo off
  echo setlocal EnableExtensions
  echo title %WTITLE%
  echo cd /d "%PDIR%"
  echo set "PYTHONUNBUFFERED=1"
  echo set "PYTHONIOENCODING=utf-8"
  echo set "PYTHONLEGACYWINDOWSSTDIO=1"
  echo echo ================= %WTITLE% =================
  echo call %PYEXE% setup.py
  echo set "RC=%%ERRORLEVEL%%"
  echo echo.
  echo echo Finished with exit code %%RC%%.
  echo echo Press any key to close this window...
  echo pause ^>nul
  echo endlocal ^& exit /b %%RC%%
) > "%RUNNER%"
start "%WTITLE%" /WAIT "%ComSpec%" /c call "%RUNNER%"
set "RC=%ERRORLEVEL%"
del /q "%RUNNER%" >nul 2>&1
exit /b %RC%

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

:RUNNER_CSDM_BUILD
:: args: install|rebuild|clean
set "MODE=%~1"
if not exist "%ROOT%%CSDM_DIR%\package.json" ( echo [INFO] %CSDM_DIR%\package.json not found. & pause & exit /b 0 )
set "RUNNER=%TEMP%\csdm_build_%MODE%_%RANDOM%.bat"
(
  echo @echo off
  echo setlocal EnableExtensions
  echo title CSDM build — %MODE%
  echo cd /d "%ROOT%%CSDM_DIR%"
  echo where nvm ^>nul 2^>^&1 ^&^& call nvm use lts ^>nul 2^>^&1
  echo set "GYP_MSVS_VERSION=2022"
  echo call npm config set engine-strict false --location^=project ^>nul
  echo call npm config set fund false --location^=project ^>nul
  echo call npm config set audit false --location^=project ^>nul
  if /I "%MODE%"=="clean" (
    echo echo [CLEAN] Removing node_modules and addon build...
    echo if exist node_modules rmdir /s /q node_modules
    echo if exist src\node\os\get-running-process-exit-code\build rmdir /s /q src\node\os\get-running-process-exit-code\build
    echo call npm cache clean --force ^>nul
  )
  echo echo ================ npm install ================
  echo call npm install
  echo set "NPM_RC=%%ERRORLEVEL%%"
  echo echo ============= node-gyp rebuild =============
  echo pushd src\node\os\get-running-process-exit-code
  echo if exist "..\..\..\..\node_modules\.bin\node-gyp.cmd" (
  echo   call "..\..\..\..\node_modules\.bin\node-gyp.cmd" rebuild --msvs_version^=2022
  echo ) else (
  echo   call npx --yes node-gyp rebuild --msvs_version^=2022
  echo )
  echo set "GYPRC=%%ERRORLEVEL%%"
  echo popd
  echo echo.
  echo if not "%%GYPRC%%"=="0" ( echo Build failed with code %%GYPRC%%. )
  echo echo Press any key to close this window...
  echo pause ^>nul
  echo if not "%%GYPRC%%"=="0" ( endlocal ^& exit /b %%GYPRC%% )
  echo endlocal ^& exit /b 0
) > "%RUNNER%"
start "CSDM build — %MODE%" /WAIT "%ComSpec%" /c call "%RUNNER%"
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

:PRINT_PREREQS
echo Repo root: %ROOT%
echo.
echo Python launcher (py.exe):
where "%SystemRoot%\py.exe" >nul 2>&1 && "%SystemRoot%\py.exe" -3 --version
echo.
echo python.exe:
where python >nul 2>&1 && python --version
echo.
echo Node and NVM:
where node >nul 2>&1 && node -v
where nvm  >nul 2>&1 && nvm version
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
