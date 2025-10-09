@echo off
setlocal EnableExtensions

rem --------------------------------------------------------------
rem  Demo2Video Launcher
rem --------------------------------------------------------------

rem Resolve the folder that contains this .bat file
set "ROOT=%~dp0"
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

rem ----------------------------------------------------------------
rem  Show the menu – the script will exit once a choice is made
rem ----------------------------------------------------------------
:menu
cls
echo ==================================================
echo          Demo2Video Launcher
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
        echo [ERROR] d2v_multi folder missing & pause
        goto :menu
    )
)
if "%sel%"=="2" (
    if exist "%ROOT%d2v_single" (
        goto :single
    ) else (
        echo [ERROR] d2v_single folder missing & pause
        goto :menu
    )
)

rem If we get here something went wrong – loop back to the menu
goto :menu


rem ----------------------------------------------------------------
rem  MULTI mode
rem ----------------------------------------------------------------
:multi
rem ---- OBS (no console needed) ---------------------------------
echo [1/4] Starting OBS...
start "" "%ROOT%obs64.exe.lnk"
timeout /t 3 >nul

rem ---- CSDM dev server (keep console open for logs) ----------
echo [2/4] Starting the CS Demo Manager dev server...
start "CSDM Dev Server" ^
      /D "%ROOT%csdm-fork" ^
      cmd /k "node scripts/develop-cli.mjs"

rem ---- D2V multi Python app (keep console open for logs) ------
echo [3/4] Starting the main Python application...
start "D2V Multi" ^
      /D "%ROOT%d2v_multi" ^
      cmd /k "python main.py"

rem ---- Give the web server a moment to start -------------------
echo [4/4] Waiting 10 seconds for the web server to start...
timeout /t 10 /nobreak >nul

rem ---- Open the web UI -----------------------------------------
echo Launching web interface in your browser...
start "" "http://localhost:5001"

rem Exit the launcher – the menu window disappears
goto :end


rem ----------------------------------------------------------------
rem  SINGLE mode
rem ----------------------------------------------------------------
:single
rem ---- OBS (no console needed) ---------------------------------
echo [1/4] Starting OBS...
start "" "%ROOT%obs64.exe.lnk"
timeout /t 3 >nul

rem ---- CSDM dev server (keep console open for logs) ----------
echo [2/4] Starting the CS Demo Manager dev server...
start "CSDM Dev Server" ^
      /D "%ROOT%csdm-fork" ^
      cmd /k "node scripts/develop-cli.mjs"

rem ---- D2V single Python app (keep console open for logs) -----
echo [3/4] Starting the main Python application...
start "D2V Single" ^
      /D "%ROOT%d2v_single" ^
      cmd /k "python main.py"

rem ---- Give the web server a moment to start -------------------
echo [4/4] Waiting 10 seconds for the web server to start...
timeout /t 10 /nobreak >nul

rem ---- Open the web UI -----------------------------------------
echo Launching web interface in your browser...
start "" "http://localhost:5001"

rem Exit the launcher
goto :end


rem ----------------------------------------------------------------
rem  Clean shutdown
rem ----------------------------------------------------------------
:end
endlocal
exit /b 0