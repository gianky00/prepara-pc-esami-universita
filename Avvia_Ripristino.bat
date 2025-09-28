@echo off
REM Questo file batch avvia lo script di ripristino post-esame con privilegi di amministratore.
REM Lo script PowerShell gestirà autonomamente la richiesta di elevazione (UAC).

echo Avvio dello script di ripristino post-esame...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0\Exam-Prep.ps1" -Mode Ripristino

echo.
echo Operazione richiesta. Controlla la finestra di PowerShell.
pause