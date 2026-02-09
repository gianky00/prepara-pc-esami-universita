# ♾️ PROGETTO: PREPARA PC ESAMI UNIVERSITÀ

Questo progetto è un toolkit di automazione basato su PowerShell progettato per configurare in modo ottimale un PC Windows prima di sostenere esami universitari online che richiedono software di proctoring.

## 📝 Panoramica del Progetto
Lo script gestisce l'intero ciclo di vita della preparazione dell'esame:
1.  **Backup:** Salva lo stato corrente del sistema (servizi, schemi energetici, impostazioni di rete).
2.  **Preparazione:** Chiude processi non consentiti, ottimizza le prestazioni (CPU High Priority, GPU Performance, QoS di rete), disabilita notifiche e pulisce file temporanei.
3.  **Ripristino:** Riporta il PC allo stato originale esattamente come era prima dell'esame.
4.  **Reporting:** Genera un report dettagliato dell'hardware e del software del sistema.

## 🛠️ Tecnologie Principali
- **PowerShell 5.1/7+**: Core della logica di automazione.
- **JSON**: Gestione della configurazione (`ExamPrep.config.json`).
- **Windows Registry & WMI/CIM**: Per le ottimizzazioni profonde del sistema.

## 🚀 Utilizzo

### Modalità Preparazione
Esegue il backup e applica le ottimizzazioni. Richiede privilegi di Amministratore.
- **Batch:** Eseguire `Avvia_Preparazione_Esame.bat`
- **PowerShell:** `.\Invoke-ExamPrep.ps1 -Mode Preparation`

### Modalità Ripristino
Ripristina lo stato salvato durante la preparazione.
- **Batch:** Eseguire `Avvia_Ripristino.bat`
- **PowerShell:** `.\Invoke-ExamPrep.ps1 -Mode Restore`

### Generazione Report
Crea un file `Report_PC_Definitivo.txt` con le specifiche del sistema.
- **Batch:** Eseguire `Avvia-Report.bat`
- **PowerShell:** `.\Invoke-ExamPrep.ps1 -Mode Report`

## 📂 Struttura dei File Chiave
- `Invoke-ExamPrep.ps1`: Il wrapper principale che gestisce l'elevazione e l'importazione del modulo.
- `ExamPrep.config.json`: File di configurazione per processi da killare, app consentite e servizi.
- `ExamPrep/ExamPrep.psm1`: Il modulo core contenente le funzioni `Start-ExamPreparation`, `Start-ExamRestore` e `New-ExamPrepReport`.
- `prepara pc esami.ps1`: Versione legacy/standalone dello script (v1.0).

## 📋 Convenzioni di Sviluppo
- **Logging:** Tutte le operazioni vengono loggate in `$env:LOCALAPPDATA\ExamPrep\ExamPrep_Log.txt`.
- **Sicurezza:** Gli script richiedono sempre l'elevazione se la modalità selezionata modifica il sistema.
- **Modularità:** La logica è separata dall'interfaccia di invocazione per facilitare i test e la manutenzione.
- **Error Handling:** Utilizzo estensivo di blocchi `try/catch` per evitare crash del sistema durante modifiche al registro o ai servizi.

## ⚠️ Note Importanti
- Il file `ExamPrep.config.json` deve essere aggiornato se il nome dell'app di proctoring cambia.
- Le ottimizzazioni di rete (Nagle's Algorithm) vengono applicate solo sull'interfaccia di rete attiva con gateway predefinito.
