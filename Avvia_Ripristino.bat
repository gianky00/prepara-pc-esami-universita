@echo off
REM Avvia lo script PowerShell in modalità Ripristino
echo Avvio del ripristino del PC allo stato pre-esame...
echo.

set "SCRIPT_PATH=%~dp0Invoke-ExamPrep.ps1"

REM Esegue lo script PowerShell. Lo script stesso gestirà l'elevazione dei privilegi.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -Mode Restore

echo.
echo Operazione completata. La finestra si chiuderà a breve.
timeout /t 5 >nul
exit /b