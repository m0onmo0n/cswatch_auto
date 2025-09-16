@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Demo2Video — Nuclear Repair

REM ==========================
REM == setup & logging     ==
REM ==========================
set "ROOT=%~dp0"
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
if not "%ROOT:~-1%"=="\" set "ROOT=%ROOT%\"

set "LOG=%ROOT%repair-env.log"
echo [%DATE% %TIME%] Starting repair... > "%LOG%"

REM repo layout checks (adjust this if your csdm-fork folder lives elsewhere)
set "CSDM=%ROOT%csdm-fork"
set "ADDON=%CSDM%\src\node\os\get-running-process-exit-code"

if not exist "%CSDM%\package.json" (
  echo ERROR: Could not find "%CSDM%\package.json". Are you running from the project root? | call :tee
  goto :fail
)

REM ==========================
REM == admin check          ==
REM ==========================
>nul 2>&1 "%SYSTEMROOT%\system32\whoami.exe" /groups | find /i "S-1-16-12288" >nul
if errorlevel 1 (
  REM fallback to the classic trick
  >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
  if NOT "%ERRORLEVEL%"=="0" (
    echo This script needs Administrator. Right-click and "Run as administrator". | call :tee
    pause
    exit /b 1
  )
)

REM ==========================
REM == function: tee        ==
REM ==========================
:tee
REM usage: some_command | call :tee
(for /f "usebackq delims=" %%L in (`more`) do (
  echo %%L
  >>"%LOG%" echo %%L
))
exit /b

REM ==========================
REM == kill stray processes ==
REM ==========================
echo. | call :tee
echo == Killing stray node/python/npm processes == | call :tee
for %%P in (node.exe npm.exe python.exe pythonw.exe) do (
  taskkill /f /im %%P >nul 2>&1
)

REM ==========================
REM == enable long paths    ==
REM ==========================
reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled >nul 2>&1
if errorlevel 1 (
  reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f >nul 2>&1
) else (
  for /f "tokens=3" %%A in ('reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled ^| find "REG_DWORD"') do set "LPE=%%A"
  if /I not "%LPE%"=="0x1" reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f >nul 2>&1
)

REM ==========================
REM == ensure Python / NVM  ==
REM ==========================
echo. | call :tee
echo == Checking Python launcher (py.exe) == | call :tee
where py >nul 2>&1
if errorlevel 1 (
  echo Python launcher not on PATH. Attempting install via winget... | call :tee
  winget install -e --id Python.Launcher --accept-source-agreements --accept-package-agreements --silent | call :tee
)

echo == Checking Python 3.x == | call :tee
py -3 --version 2>&1 | call :tee
if errorlevel 1 (
  echo Installing Python 3.13 via winget... | call :tee
  winget install -e --id Python.Python.3.13 --accept-source-agreements --accept-package-agreements --silent | call :tee
)

REM put Python into this session PATH (helps immediately)
for /f "delims=" %%P in ('py -3 -c "import sys,os;print(os.path.dirname(sys.executable))" 2^>nul') do set "PYDIR=%%P"
if defined PYDIR (
  set "PATH=%PYDIR%;%PYDIR%\Scripts;%PATH%"
)

echo. | call :tee
echo == Checking NVM/Node == | call :tee
where nvm >nul 2>&1
if errorlevel 1 (
  echo Installing NVM via winget... | call :tee
  winget install -e --id CoreyButler.NVMforWindows --accept-source-agreements --accept-package-agreements --silent | call :tee
  setx NVM_HOME "C:\Program Files\nvm" >nul
  setx NVM_SYMLINK "C:\Program Files\nodejs" >nul
  set  "NVM_HOME=C:\Program Files\nvm"
  set  "NVM_SYMLINK=C:\Program Files\nodejs"
  set  "PATH=%NVM_HOME%;%NVM_SYMLINK%;%PATH%"
) else (
  for /f "usebackq tokens=2,*" %%A in (`reg query HKCU\Environment /v NVM_HOME 2^>nul ^| find "REG_SZ"`) do set "NVM_HOME=%%B"
  if not defined NVM_HOME set "NVM_HOME=C:\Program Files\nvm"
  set "NVM_SYMLINK=C:\Program Files\nodejs"
  set "PATH=%NVM_HOME%;%NVM_SYMLINK%;%PATH%"
)

echo Using NVM at: %NVM_HOME% | call :tee

REM install/use Node LTS for a clean baseline
call nvm ls | findstr /i "lts" >nul || (call nvm install lts | call :tee)
call nvm use lts | call :tee
if errorlevel 1 (
  echo nvm use lts failed, trying Node 22... | call :tee
  call nvm install 22 | call :tee
  call nvm use 22 | call :tee
)

for /f "delims=" %%V in ('node -v 2^>nul') do set "NODEVER=%%V"
if not defined NODEVER (
  echo ERROR: Node is still not available in PATH. | call :tee
  goto :fail
)
echo Node version: %NODEVER% | call :tee

REM ==========================
REM == prepare node-gyp     ==
REM ==========================
set "GYP_MSVS_VERSION=2022"
set "npm_config_msvs_version=2022"
set "npm_config_python=py -3"

REM ==========================
REM == deep clean           ==
REM ==========================
echo. | call :tee
echo == Deep cleaning node_modules and caches == | call :tee

pushd "%CSDM%"
  call npm cache clean --force | call :tee

  if exist node_modules (
    echo Removing node_modules ... | call :tee
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "try{if(Test-Path 'node_modules'){Remove-Item -LiteralPath '\\?\%CD%\node_modules' -Recurse -Force -ErrorAction Stop}}catch{$Host.SetShouldExit(1)}" | call :tee
    if exist node_modules (
      echo node_modules still present; trying robocopy zero-mirror... | call :tee
      robocopy "%CD%" "%CD%\_EMPTY_" /MIR /NFL /NDL /NJH /NJS /NP >nul & rmdir /s /q "_EMPTY_" >nul 2>&1
      rmdir /s /q node_modules >nul 2>&1
    )
  )
  if exist package-lock.json del /f /q package-lock.json >nul 2>&1
popd

REM clean addon build folder
if exist "%ADDON%\build" rmdir /s /q "%ADDON%\build" >nul 2>&1

REM ==========================
REM == install dependencies ==
REM ==========================
pushd "%CSDM%"
  echo. | call :tee
  echo == Installing JS dependencies (first try: npm ci) == | call :tee
  if exist package-lock.json (
    call npm ci | call :tee
    if errorlevel 1 (
      echo npm ci failed, trying npm install --no-optional ... | call :tee
      call npm install --no-optional | call :tee
    )
  ) else (
    call npm install --no-optional | call :tee
  )

  if errorlevel 1 (
    echo npm dependency install failed. | call :tee
    goto :fail_pop
  )

  echo. | call :tee
  echo == Forcing esbuild binary install == | call :tee
  if exist node_modules\esbuild\install.js (
    node node_modules\esbuild\install.js | call :tee
  ) else (
    call npm rebuild esbuild | call :tee
  )

  echo. | call :tee
  echo == Rebuilding registry-js native module == | call :tee
  if exist node_modules\registry-js (
    pushd node_modules\registry-js
      call npx --yes node-gyp rebuild --msvs_version=2022 | call :tee
    popd
  )
popd

REM ==========================
REM == rebuild custom addon ==
REM ==========================
echo. | call :tee
echo == Rebuilding get-running-process-exit-code addon == | call :tee
if exist "%ADDON%" (
  pushd "%ADDON%"
    if exist build rmdir /s /q build >nul 2>&1
    call npx --yes node-gyp configure --msvs_version=2022 | call :tee
    call npx --yes node-gyp build     --msvs_version=2022 | call :tee
    if errorlevel 1 goto :fail_pop
  popd
) else (
  echo WARNING: addon path not found: %ADDON% | call :tee
)

echo. | call :tee
echo == SUCCESS: environment repaired. == | call :tee
echo Log: %LOG% | call :tee
pause
exit /b 0

:fail_pop
popd

:fail
echo. | call :tee
echo == FAILED. See log: %LOG% == | call :tee
pause
exit /b 1
