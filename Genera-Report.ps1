# =================================================================
#  GENERATORE DI REPORT DI SISTEMA - v12.0 (Modern PowerShell)
# =================================================================
#  Questo script usa i moderni cmdlet di PowerShell (Get-CimInstance)
#  per la massima affidabilità e compatibilità.
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

    Add-Content -Path $reportFile -Value "`n`n--- $Title ---`n"

    try {
        # Esegue il comando e cattura l'output formattato come stringa
        $output = & $Command | Out-String
        Add-Content -Path $reportFile -Value $output
        Write-Host "[SUCCESS] Report per '$Title' completato."
    } catch {
        $errorMessage = "ERRORE CRITICO DURANTE L'ESECUZIONE DI '$Title': $($_.Exception.Message)"
        Add-Content -Path $reportFile -Value $errorMessage
        Write-Host "[ERROR] Esecuzione di '$Title' fallita. Dettagli nel report." -ForegroundColor Red
    }
}

Write-Host "[INFO] Inizio generazione report. L'operazione potrebbe richiedere alcuni istanti..."
Write-Host "-----------------------------------------------------------------"

# Esecuzione sequenziale e robusta di ogni comando
Run-And-Log -Title "INFORMAZIONI DI SISTEMA (SYSTEMINFO)" -Command { systeminfo }
Run-And-Log -Title "INFORMAZIONI PROCESSORE (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List }
Run-And-Log -Title "INFORMAZIONI SCHEDA VIDEO (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_VideoController | Select-Object Name, DriverVersion, AdapterRAM | Format-List }
Run-And-Log -Title "INFORMAZIONI MEMORIA RAM (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object BankLabel, @{n="Capacity(GB)";e={[math]::Round($_.Capacity / 1GB)}}, MemoryType, Speed | Format-Table }
Run-And-Log -Title "INFORMAZIONI DISCHI FISICI (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Model, @{n="Size(GB)";e={[math]::Round($_.Size / 1GB)}}, InterfaceType | Format-Table }
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