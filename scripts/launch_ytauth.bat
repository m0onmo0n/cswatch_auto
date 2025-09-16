@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Demo2Video — YouTube Auth Launcher

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

:: where the auth scripts live (scripts\ preferred; root fallback)
set "RUN_MULTI=%SCRIPTS%youtube_auth_multi.bat"
if not exist "%RUN_MULTI%" set "RUN_MULTI=%ROOT%youtube_auth_multi.bat"

set "RUN_SINGLE=%SCRIPTS%youtube_auth_single.bat"
if not exist "%RUN_SINGLE%" set "RUN_SINGLE=%ROOT%youtube_auth_single.bat"

:menu
cls
echo ==================================================
echo             Demo2Video — YouTube Auth
echo ==================================================
echo   [M] D2V Multi (pipelined)
echo   [S] D2V Single (classic)
echo   [Q] Quit
echo.

choice /C MSQ /N /M "Select: "
set "sel=%errorlevel%"

if "%sel%"=="3" goto :end

if "%sel%"=="1" (
  set "TARGET=%RUN_MULTI%"
) else if "%sel%"=="2" (
  set "TARGET=%RUN_SINGLE%"
) else (
  echo Unexpected selection. Try again.
  timeout /t 1 >nul
  goto :menu
)

if not exist "%TARGET%" (
  echo [ERROR] Not found:
  echo   %TARGET%
  echo.
  echo Expected in scripts\ or repo root.
  echo Press any key to return to the menu...
  pause >nul
  goto :menu
)

echo.
echo Launching "%TARGET%" in a new window...
echo (Close that window when finished to return here.)
echo --------------------------------------------------

:: open a new console that stays open; we wait for it to close
start "YouTube Auth" /D "%ROOT%" /WAIT "%ComSpec%" /k call "%TARGET%"
set "EXITCODE=%ERRORLEVEL%"

echo --------------------------------------------------
echo "%TARGET%" exited with code %EXITCODE%.
echo.
echo Press any key to return to the menu...
pause >nul
goto :menu

:end
endlocal
exit /b 0
