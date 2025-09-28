@echo off
:: Imposta la codifica dei caratteri per supportare l'italiano
chcp 65001 > nul

:: ============================================================================
::  SCRIPT PER AVVIARE LA GENERAZIONE DEL REPORT DI SISTEMA
::  Autore: Jules
::  Versione: 1.0
:: ============================================================================
::
::  DESCRIZIONE:
::  Questo file batch avvia lo script PowerShell "Genera-Report.ps1"
::  con i privilegi di amministratore necessari per la raccolta dei dati.
::
:: ============================================================================

:: 1. VERIFICA DEI PRIVILEGI DI AMMINISTRATORE
:: Controlla se lo script è già in esecuzione come amministratore.
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

:: Se il controllo fallisce (codice di errore diverso da 0), non abbiamo i privilegi.
if '%errorlevel%' NEQ '0' (
    echo Richiesta dei privilegi di amministratore in corso...
    echo Se richiesto, clicca "Si" nella finestra di Controllo Account Utente (UAC).
    echo.
    :: Riavvia se stesso con i privilegi di amministratore usando PowerShell.
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Se siamo qui, abbiamo i privilegi di amministratore.
cls
echo Privilegi di amministratore ottenuti.
echo.

:: 2. ESECUZIONE DELLO SCRIPT POWERSHELL
echo =================================================================
echo  Avvio dello script per la generazione del report...
echo =================================================================
echo.
echo Lo script sta raccogliendo le informazioni di sistema.
echo L'operazione potrebbe richiedere alcuni istanti.
echo.
echo Al termine, troverai il file 'Report_PC_Definitivo.txt'
echo nella cartella 'ExamPrep'.
echo.

:: Avvia lo script PowerShell.
:: -NoProfile: non carica il profilo utente, rendendo l'avvio più rapido e pulito.
:: -ExecutionPolicy Bypass: consente l'esecuzione dello script anche se non firmato.
:: -File: specifica il percorso dello script da eseguire.
:: "%~dp0" si espande nel percorso della directory in cui si trova questo file batch.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ExamPrep\Genera-Report.ps1"

echo.
echo =================================================================
echo  Esecuzione terminata.
echo =================================================================
echo.
echo Lo script ha terminato la sua esecuzione.
echo Controlla i messaggi qui sopra per l'esito.
echo.
echo Premi un tasto per chiudere questa finestra.
pause
exit