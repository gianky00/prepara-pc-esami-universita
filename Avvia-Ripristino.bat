@echo off
:: Imposta la codifica dei caratteri per supportare l'italiano
chcp 65001 > nul

:: ============================================================================
::  SCRIPT PER AVVIARE IL RIPRISTINO DEL PC DOPO L'ESAME
::  Autore: Jules
::  Versione: 1.0
:: ============================================================================
::
::  DESCRIZIONE:
::  Questo file batch avvia la funzione "Start-ExamRestore" del modulo
::  PowerShell "ExamPrep.psm1" con i privilegi di amministratore necessari.
::
:: ============================================================================

:: 1. VERIFICA DEI PRIVILEGI DI AMMINISTRATORE
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Richiesta dei privilegi di amministratore in corso...
    echo Se richiesto, clicca "Si" nella finestra di Controllo Account Utente (UAC).
    echo.
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Se siamo qui, abbiamo i privilegi di amministratore.
cls
echo Privilegi di amministratore ottenuti.
echo.

:: 2. ESECUZIONE DELLO SCRIPT POWERSHELL
echo =================================================================
echo    AVVIO RIPRISTINO CONFIGURAZIONE PC
echo =================================================================
echo.
echo Lo script ora ripristinera' le impostazioni originali
echo del sistema utilizzando il backup creato in precedenza.
echo.

:: Avvia PowerShell, importa il modulo ed esegue la funzione di ripristino.
:: Si importa il modulo puntando alla cartella per usare il manifesto (.psd1), metodo più robusto.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {Import-Module '%~dp0ExamPrep'; Start-ExamRestore}"

echo.
echo =================================================================
echo         OPERAZIONE DI RIPRISTINO COMPLETATA
echo =================================================================
echo.
echo Il tuo PC e' tornato alla configurazione standard.
echo Grazie per aver utilizzato ExamPrep!
echo.
echo Premi un tasto per chiudere questa finestra.
pause > nul
exit