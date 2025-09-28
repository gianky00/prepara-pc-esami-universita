<#
.SYNOPSIS
    Genera un report dettagliato dell'hardware e del software del sistema.

.DESCRIPTION
    Questo script raccoglie informazioni complete sul sistema utilizzando una combinazione di
    utility di sistema e cmdlet WMI/CIM moderni. L'output viene formattato e salvato
    in un file di testo chiamato "Report_PC_Definitivo.txt" nella stessa directory dello script.
    Il file viene salvato con codifica UTF-8 con BOM per garantire la compatibilità con Notepad.

.NOTES
    Autore: Jules
    Versione: 1.0
    Data: 28/09/2025
#>

# Imposta la directory di lavoro sulla posizione dello script
$scriptPath = $PSScriptRoot
Set-Location $scriptPath

# Definisce il nome del file di report
$outputFile = "Report_PC_Definitivo.txt"

# Inizializza una stringa per contenere l'intero report
$reportContent = @"
=================================================================
             REPORT CONFIGURAZIONE PC - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
=================================================================

Questo report contiene un riepilogo della configurazione hardware e software
del computer. È stato generato per fornire una panoramica dettagliata del sistema.

"@

# --- INFORMAZIONI DI SISTEMA (SYSTEMINFO) ---
$reportContent += @"

--- INFORMAZIONI DI SISTEMA (SYSTEMINFO) ---

"@
$reportContent += (systeminfo | Out-String)
$reportContent += "`n"

# --- INFORMAZIONI PROCESSORE (Get-CimInstance) ---
$reportContent += @"
--- INFORMAZIONI PROCESSORE (Get-CimInstance) ---

"@
$cpuInfo = Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
$reportContent += ($cpuInfo | Format-Table | Out-String)
$reportContent += "`n"

# --- INFORMAZIONI SCHEDA VIDEO (Get-CimInstance) ---
$reportContent += @"
--- INFORMAZIONI SCHEDA VIDEO (Get-CimInstance) ---

"@
$gpuInfo = Get-CimInstance -ClassName Win32_VideoController | Select-Object Name, DriverVersion, AdapterRAM
$reportContent += ($gpuInfo | Format-Table | Out-String)
$reportContent += "`n"

# --- INFORMAZIONI MEMORIA RAM (Get-CimInstance) ---
$reportContent += @"
--- INFORMAZIONI MEMORIA RAM (Get-CimInstance) ---

"@
$ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory | ForEach-Object {
    [PSCustomObject]@{
        'BankLabel'    = $_.BankLabel
        'Capacity(GB)' = [math]::Round($_.Capacity / 1GB)
        'MemoryType'   = $_.MemoryType
        'Speed'        = $_.Speed
    }
}
$reportContent += ($ramInfo | Format-Table | Out-String)
$reportContent += "`n"

# --- INFORMAZIONI DISCHI FISICI (Get-CimInstance) ---
$reportContent += @"
--- INFORMAZIONI DISCHI FISICI (Get-CimInstance) ---

"@
$diskInfo = Get-CimInstance -ClassName Win32_DiskDrive | ForEach-Object {
    [PSCustomObject]@{
        'Model'         = $_.Model
        'Size(GB)'      = [math]::Round($_.Size / 1GB)
        'InterfaceType' = $_.InterfaceType
    }
}
$reportContent += ($diskInfo | Format-Table | Out-String)
$reportContent += "`n"


# --- CONFIGURAZIONE DI RETE (IPCONFIG) ---
$reportContent += @"
--- CONFIGURAZIONE DI RETE (IPCONFIG) ---

"@
$reportContent += (ipconfig /all | Out-String)
$reportContent += "`n"

# --- PIANI DI RISPARMIO ENERGETICO (POWERCFG) ---
$reportContent += @"
--- PIANI DI RISPARMIO ENERGETICO (POWERCFG) ---

"@
$reportContent += (powercfg /list | Out-String)
$reportContent += "`n"

# --- FINE DEL REPORT ---
$reportContent += @"
=================================================================
                     FINE DEL REPORT
=================================================================
"@

# Scrive l'intero contenuto nel file di output con la codifica corretta
try {
    $reportContent | Out-File -FilePath $outputFile -Encoding utf8BOM -Force
    Write-Host "Report generato con successo: $outputFile"
}
catch {
    Write-Error "Errore durante la scrittura del file di report: $($_.Exception.Message)"
}

Write-Host "Operazione completata. Premi un tasto per uscire."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")