@echo off
setlocal

:: =================================================================
::  AVVIO RIPRISTINO POST-ESAME - v9.0 (Modalita' Élite)
:: =================================================================
::  Questo file avvia lo script di ripristino post-esame con
::  privilegi di amministratore per annullare tutte le ottimizzazioni.
:: =================================================================

echo.
echo  [INFO] Avvio Ripristino Post-Esame in corso...
echo.
echo  [!] Verranno ripristinate tutte le impostazioni modificate
echo      durante la fase di preparazione.
echo.
echo  [!] Potrebbe essere richiesta l'autorizzazione di Amministratore (UAC).
echo.
echo  =================================================================
pause
cls

:: --- Richiesta Privilegi di Amministratore ---
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [ERRORE] Privilegi di amministratore richiesti.
    echo          Tentativo di riavvio automatico dello script...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    goto :eof
)
:: --- Esecuzione con Privilegi Ottenuti ---

echo [SUCCESS] Privilegi di amministratore ottenuti.
echo [INFO]    Avvio del modulo PowerShell...
echo.

:: Definisce il percorso del modulo e dei file
set "MODULE_PATH=%~dp0ExamPrep"
set "CONFIG_PATH=%~dp0ExamPrep.config.json"
set "LOG_PATH=%~dp0Exam-Prep.log"

:: Comando PowerShell da eseguire
:: La funzione di ripristino ora richiede anche il ConfigPath per ripristinare la priorità del processo.
set "ps_command=Import-Module -Name '%MODULE_PATH%' -Force; Start-ExamRestore -ConfigPath '%CONFIG_PATH%' -LogPath '%LOG_PATH%' -Verbose"

:: Avvia PowerShell con il comando
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -Command "&{%ps_command%}"

endlocal