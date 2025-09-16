@echo off
setlocal EnableExtensions
title Demo2Video Launcher
CLS
echo =================================================================
echo == CS Demo Processor - Application Launcher                  ==
echo =================================================================
echo.

set "ROOT=%~dp0"
for %%I in ("%ROOT%") do set "ROOT=%%~fI"



:menu
cls
echo ==================================================
echo                 Demo2Video Launcher
echo ==================================================
echo   [M] D2V Multi (pipelined)
echo   [S] D2V Single (classic)
echo   [Q] Quit
echo.
choice /C MSQ /N /M "Select: "
set "sel=%errorlevel%"

if "%sel%"=="3" goto :end

if "%sel%"=="1" (
  if exist "%ROOT%d2v_multi" (
    goto :multi
  ) else (
    echo [ERROR] error & pause
  )
) else if "%sel%"=="2" (
  if exist "%ROOT%d2v_single" (
    goto :single
  ) else (
    echo [ERROR] error & pause
  )
) else (
  echo Unexpected selection. & timeout /t 1 >nul
)
goto :menu


:multi
:: --- Start OBS ---
echo [1/4] Starting OBS...
start "OBS" cmd /c ".\obs64.exe.lnk" 
timeout /t 3
:: --- Start the CSDM Node.js development server ---
echo [2/4] Starting the CS Demo Manager dev server...
start "CSDM Dev Server" cmd /c "cd csdm-fork && node scripts/develop-cli.mjs"

:: --- Start the main Python application (web server and worker) ---
echo [3/4] Starting the main Python application...
start "d2v multi" cmd /c "cd d2v_multi &% python main.py"

:: --- Wait for the server to initialize ---
echo [4/4] Waiting 10 seconds for the web server to start...
timeout /t 10 /nobreak > nul

:: --- Open the web interface in the default browser ---
echo Launching web interface in your browser...
start http://localhost:5001
goto :menu

:single
:: --- Start OBS ---
echo [1/4] Starting OBS...
start "OBS" cmd /c ".\obs64.exe.lnk" 
timeout /t 3
:: --- Start the CSDM Node.js development server ---
echo [2/4] Starting the CS Demo Manager dev server...
start "CSDM Dev Server" cmd /c "cd csdm-fork && node scripts/develop-cli.mjs"

:: --- Start the main Python application (web server and worker) ---
echo [3/4] Starting the main Python application...
start "d2v single" cmd /c "cd d2v_single &% python main.py"

:: --- Wait for the server to initialize ---
echo [4/4] Waiting 10 seconds for the web server to start...
timeout /t 10 /nobreak > nul

:: --- Open the web interface in the default browser ---
echo Launching web interface in your browser...
start http://localhost:5001
goto :menu


:end
endlocal
exit /b 0
