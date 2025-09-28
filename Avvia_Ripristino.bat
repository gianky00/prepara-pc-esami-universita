@echo off
REM Avvia lo script di ripristino post-esame in modalità professionale.
REM Importa il modulo ExamPrep e chiama la funzione Start-ExamRestore.

echo.
echo =======================================================
echo      AVVIO RIPRISTINO POST-ESAME - Modalita' Professionale
echo =======================================================
echo.
echo Verra' aperta una nuova finestra di PowerShell per eseguire le operazioni.
echo Questa finestra si chiudera' al termine.
echo.

REM Definisce il comando PowerShell da eseguire.
REM -ExecutionPolicy Bypass: Consente l'esecuzione dello script.
REM -Command "& {...}": Esegue un blocco di comandi.
REM   Import-Module: Carica il nostro modulo ExamPrep.
REM   Start-ExamRestore: Esegue la funzione di ripristino.
REM   -LogPath: Specifica dove salvare il file di log.
REM   -Verbose: Mostra tutti i dettagli delle operazioni a schermo.
set "ps_command=powershell.exe -ExecutionPolicy Bypass -Command \"& {Import-Module -Name '%~dp0ExamPrep' -Force; Start-ExamRestore -LogPath '%~dp0Exam-Prep.log' -Verbose}\""

REM Esegue lo script PowerShell con privilegi elevati.
REM Lo script PowerShell stesso gestirà la richiesta di elevazione (UAC).
%ps_command%

echo.
echo Operazione terminata. Controlla la finestra di PowerShell e il file Exam-Prep.log per i dettagli.
pause