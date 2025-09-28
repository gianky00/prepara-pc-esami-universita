@echo off
setlocal

:: =================================================================
::  AVVIO PREPARAZIONE ESAME - v6.0 (Modalita' Élite)
:: =================================================================
::  Questo file avvia lo script di preparazione per l'esame con
::  privilegi di amministratore e ottimizzazioni avanzate.
:: =================================================================

echo.
echo  [INFO] Avvio Preparazione Esame in corso...
echo.
echo  [!] Verranno applicate ottimizzazioni di livello ÉLITE per:
echo      - CPU e GPU (massima priorita' al proctoring)
echo      - Sistema e RAM (interfaccia piu' reattiva)
echo      - Rete (minima latenza con QoS e altre tecniche)
echo.
echo  [!] Potrebbe essere richiesta l'autorizzazione di Amministratore (UAC).
echo.
echo  [?] Lo script scansionera' i processi. Se trovera' programmi
echo      non configurati, ti chiedera' cosa fare.
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

:: Definisce il percorso del modulo e dei file di configurazione/log
set "MODULE_PATH=%~dp0ExamPrep"
set "CONFIG_PATH=%~dp0ExamPrep.config.json"
set "LOG_PATH=%~dp0Exam-Prep.log"

:: Comando PowerShell da eseguire
set "ps_command=Import-Module -Name '%MODULE_PATH%' -Force; Start-ExamPreparation -ConfigPath '%CONFIG_PATH%' -LogPath '%LOG_PATH%' -Verbose"

:: Avvia PowerShell con il comando
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -Command "&{%ps_command%}"

endlocal