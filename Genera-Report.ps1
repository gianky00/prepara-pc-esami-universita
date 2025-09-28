# =================================================================
#  GENERATORE DI REPORT DI SISTEMA - v10.0 (PowerShell Edition)
# =================================================================
#  Questo script raccoglie informazioni dettagliate e gestisce
#  gli errori in modo robusto, salvando tutto in un file di testo.
# =================================================================

$reportFile = Join-Path $PSScriptRoot "Report_PC_Definitivo.txt"
$ErrorActionPreference = "SilentlyContinue" # Sopprime i messaggi di errore a console, ma non gli errori stessi

Function Write-SectionHeader {
    param([string]$Title)
    " "
    " "
    "--- $Title ---"
    " "
}

Function Run-And-Log {
    param(
        [string]$Title,
        [scriptblock]$Command
    )
    Write-SectionHeader -Title $Title
    try {
        # Esegue il comando e cattura l'output (sia standard che errori)
        $output = & $Command 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -and -not $output) {
            "Comando fallito o non ha prodotto output."
        } else {
            $output
        }
    } catch {
        "ERRORE CRITICO DURANTE L'ESECUZIONE DI '$Title':"
        $_.Exception.Message
    }
}

# Pulisce il report precedente
if (Test-Path $reportFile) { Remove-Item $reportFile }

# Esegue tutti i comandi e salva l'output nel file di report
(
    Run-And-Log -Title "INFORMAZIONI DI SISTEMA (SYSTEMINFO)" -Command { systeminfo }
    Run-And-Log -Title "INFORMAZIONI PROCESSORE (WMIC CPU)" -Command { wmic cpu get Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed /format:list }
    Run-And-Log -Title "INFORMAZIONI SCHEDA VIDEO (WMIC GPU)" -Command { wmic path win32_videocontroller get Name, DriverVersion, AdapterRAM /format:list }
    Run-And-Log -Title "INFORMAZIONI MEMORIA RAM (WMIC MEMORY)" -Command { wmic MemoryChip get BankLabel, Capacity, MemoryType, Speed /format:list }
    Run-And-Log -Title "INFORMAZIONI DISCHI FISICI (WMIC DISKDRIVE)" -Command { wmic diskdrive get Model, Size, InterfaceType /format:list }
    Run-And-Log -Title "CONFIGURAZIONE DI RETE (IPCONFIG)" -Command { ipconfig /all }
    Run-And-Log -Title "PIANI DI RISPARMIO ENERGETICO (POWERCFG)" -Command { powercfg /list }

) | Out-File -FilePath $reportFile -Encoding UTF8 -Append

Write-Host "[SUCCESS] Report creato con successo in '$reportFile'."
Write-Host "          Il file verra' ora aperto..."

Start-Process notepad $reportFile

Write-Host "`nOperazione completata."