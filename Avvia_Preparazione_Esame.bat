@echo off
REM Questo file batch avvia lo script di preparazione per l'esame con privilegi di amministratore.
REM Lo script PowerShell gestirà autonomamente la richiesta di elevazione (UAC).

echo Avvio dello script di preparazione per l'esame...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0\Exam-Prep.ps1" -Mode Preparazione

echo.
echo Operazione richiesta. Controlla la finestra di PowerShell.
pause