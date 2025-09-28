@echo off
REM Avvia lo script PowerShell in modalità Report
echo Avvio della generazione del report di sistema...
echo.

set "SCRIPT_PATH=%~dp0Invoke-ExamPrep.ps1"

REM Esegue lo script PowerShell. La modalità Report non richiede privilegi elevati.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -Mode Report

echo.
echo Operazione completata. La finestra si chiuderà a breve.
timeout /t 10 >nul
exit /b