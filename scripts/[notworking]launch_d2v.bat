@echo off
setlocal EnableExtensions
title Demo2Video Launcher

set "ROOT=%~dp0"
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "LEG_MULTI=%ROOT%run_multi.bat"
set "LEG_SINGLE=%ROOT%run_single.bat"

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
  if exist "%LEG_MULTI%" (
    start "D2V Multi (runner)"  /D "%ROOT%" cmd /k call "%LEG_MULTI%" multi
  ) else (
    echo [ERROR] Missing scripts\run.bat and run_multi.bat & pause
  )
) else if "%sel%"=="2" (
  if exist "%LEG_SINGLE%" (
    start "D2V Single (runner)" /D "%ROOT%" cmd /k call "%LEG_SINGLE%" single
  ) else (
    echo [ERROR] Missing scripts\run.bat and run_single.bat & pause
  )
) else (
  echo Unexpected selection. & timeout /t 1 >nul
)
goto :menu

:end
endlocal
exit /b 0
