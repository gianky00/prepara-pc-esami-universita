@echo off
REM Avvia lo script PowerShell in modalità Preparazione
echo Avvio della preparazione del PC per l'esame...
echo.

set "SCRIPT_PATH=%~dp0Invoke-ExamPrep.ps1"

REM Esegue lo script PowerShell. Lo script stesso gestirà l'elevazione dei privilegi.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -Mode Preparation

echo.
echo Operazione completata. La finestra si chiuderà a breve.
timeout /t 5 >nul
exit /b