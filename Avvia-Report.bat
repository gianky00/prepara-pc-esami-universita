@echo off
:: =================================================================
::  AVVIO REPORT DI SISTEMA (PowerShell Edition)
:: =================================================================
::  Questo file avvia lo script PowerShell per generare il report
::  e mantiene questa finestra aperta per mostrare i messaggi.
:: =================================================================

echo [INFO] Avvio dello script di report PowerShell...
echo.

:: Esegue lo script PowerShell, mantenendo la finestra aperta al termine (-NoExit)
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0\Genera-Report.ps1"

echo.
echo [FINALE] L'operazione e' terminata. Puoi chiudere questa finestra.
echo.

:: Aggiungo un'ulteriore pausa per massima sicurezza
pause