# =================================================================
#  GENERATORE DI REPORT DI SISTEMA - v13.0 (Correzione Encoding)
# =================================================================
#  Usa Get-CimInstance e forza l'encoding UTF8 con BOM per massima
#  affidabilità, compatibilità e leggibilità del report.
# =================================================================

$reportFile = Join-Path $PSScriptRoot "Report_PC_Definitivo.txt"
$ErrorActionPreference = "SilentlyContinue"

# Pulisce il report precedente e scrive l'intestazione con un BOM (Byte Order Mark)
# Questo è FONDAMENTALE per far sì che Notepad legga correttamente i caratteri.
$header = @"
=================================================================
                REPORT DI SISTEMA - $(Get-Date)
=================================================================
"@
Set-Content -Path $reportFile -Value $header -Encoding utf8BOM

# Funzione per eseguire un comando e scrivere il suo output nel file di report
Function Run-And-Log {
    param(
        [string]$Title,
        [scriptblock]$Command
    )

    # Scrive l'intestazione della sezione, sempre con l'encoding corretto
    Add-Content -Path $reportFile -Value "`n`n--- $Title ---`n" -Encoding UTF8

    # Esegue il comando e cattura tutto l'output come stringa per controllare l'encoding
    try {
        $output = & $Command 2>&1 | Out-String
        Add-Content -Path $reportFile -Value $output -Encoding UTF8
        Write-Host "[SUCCESS] Report per '$Title' completato."
    } catch {
        $errorMessage = "ERRORE CRITICO DURANTE L'ESECUZIONE DI '$Title': $($_.Exception.Message)"
        Add-Content -Path $reportFile -Value $errorMessage -Encoding UTF8
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

$footer = @"

=================================================================
                     FINE DEL REPORT
=================================================================
"@
Add-Content -Path $reportFile -Value $footer -Encoding UTF8

Write-Host "-----------------------------------------------------------------"
Write-Host "[SUCCESS] Report creato con successo in '$reportFile'."
Write-Host "          Il file verra' ora aperto..."

Start-Process notepad $reportFile

Write-Host "`nOperazione completata."