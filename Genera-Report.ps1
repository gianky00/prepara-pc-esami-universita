# =================================================================
#  GENERATORE DI REPORT DI SISTEMA - v11.0 (PowerShell Stabile)
# =================================================================
#  Questo script raccoglie informazioni e gestisce gli errori in
#  modo robusto, scrivendo direttamente su file per massima stabilità.
# =================================================================

$reportFile = Join-Path $PSScriptRoot "Report_PC_Definitivo.txt"
$ErrorActionPreference = "SilentlyContinue"

# Pulisce il report precedente e scrive l'intestazione
Remove-Item $reportFile -ErrorAction SilentlyContinue
Add-Content -Path $reportFile -Value "================================================================="
Add-Content -Path $reportFile -Value "                REPORT DI SISTEMA - $(Get-Date)"
Add-Content -Path $reportFile -Value "================================================================="

# Funzione per eseguire un comando e scrivere il suo output nel file di report
Function Run-And-Log {
    param(
        [string]$Title,
        [scriptblock]$Command
    )

    # Scrive l'intestazione della sezione
    Add-Content -Path $reportFile -Value "`n`n--- $Title ---`n"

    # Esegue il comando e reindirizza tutto l'output (standard e errori) al file
    try {
        & $Command *>> $reportFile
        Write-Host "[SUCCESS] Report per '$Title' completato."
    } catch {
        Add-Content -Path $reportFile -Value "ERRORE CRITICO DURANTE L'ESECUZIONE DI '$Title': $($_.Exception.Message)"
        Write-Host "[ERROR] Esecuzione di '$Title' fallita. Dettagli nel report." -ForegroundColor Red
    }
}

# Esecuzione sequenziale e robusta di ogni comando
Write-Host "[INFO] Inizio generazione report. L'operazione potrebbe richiedere alcuni istanti..."
Write-Host "-----------------------------------------------------------------"

Run-And-Log -Title "INFORMAZIONI DI SISTEMA (SYSTEMINFO)" -Command { systeminfo }
Run-And-Log -Title "INFORMAZIONI PROCESSORE (WMIC CPU)" -Command { wmic cpu get Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed /format:list }
Run-And-Log -Title "INFORMAZIONI SCHEDA VIDEO (WMIC GPU)" -Command { wmic path win32_videocontroller get Name, DriverVersion, AdapterRAM /format:list }
Run-And-Log -Title "INFORMAZIONI MEMORIA RAM (WMIC MEMORY)" -Command { wmic MemoryChip get BankLabel, Capacity, MemoryType, Speed /format:list }
Run-And-Log -Title "INFORMAZIONI DISCHI FISICI (WMIC DISKDRIVE)" -Command { wmic diskdrive get Model, Size, InterfaceType /format:list }
Run-And-Log -Title "CONFIGURAZIONE DI RETE (IPCONFIG)" -Command { ipconfig /all }
Run-And-Log -Title "PIANI DI RISPARMIO ENERGETICO (POWERCFG)" -Command { powercfg /list }

Add-Content -Path $reportFile -Value "`n`n================================================================="
Add-Content -Path $reportFile -Value "                     FINE DEL REPORT"
Add-Content -Path $reportFile -Value "================================================================="

Write-Host "-----------------------------------------------------------------"
Write-Host "[SUCCESS] Report creato con successo in '$reportFile'."
Write-Host "          Il file verra' ora aperto..."

Start-Process notepad $reportFile

Write-Host "`nOperazione completata."