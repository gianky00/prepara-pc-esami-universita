<#
.SYNOPSIS
Wrapper script per il modulo ExamPrep. Gestisce l'elevazione dei privilegi
e avvia le modalità di preparazione, ripristino o reportistica.

.PARAMETER Mode
Specifica la modalità operativa. Valori accettati: 'Preparation', 'Restore', 'Report'.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Preparation", "Restore", "Report")]
    [string]$Mode
)

# Funzione per garantire l'esecuzione come Amministratore
function Ensure-Admin {
    if (-not ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Richiesta di privilegi di amministratore per eseguire la modalità '$Mode'..."
        $psExe = (Get-Process -Id $PID).Path
        try {
            Start-Process $psExe -Verb RunAs -ArgumentList "-NoProfile -File `"$PSCommandPath`" -Mode $Mode" -ErrorAction Stop
        }
        catch {
            Write-Error "Impossibile elevare i privilegi. Errore: $($_.Exception.Message)"
        }
        exit
    }
}

# --- Blocco Principale ---
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $scriptRoot "ExamPrep.config.json"
# Costruisce correttamente il percorso al file del modulo, annidando Join-Path
$modulePath = Join-Path -Path (Join-Path -Path $scriptRoot -ChildPath "ExamPrep") -ChildPath "ExamPrep.psm1"
$logDir = Join-Path $env:LOCALAPPDATA "ExamPrep"
$logPath = Join-Path $logDir "ExamPrep_Log.txt"
$reportPath = Join-Path $scriptRoot "Report_PC_Definitivo.txt"

# Crea la directory di log se non esiste
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Esegue la modalità richiesta
switch ($Mode) {
    "Preparation" {
        Ensure-Admin
        Write-Host "Avvio modalità Preparazione..." -ForegroundColor Green
        try {
            Import-Module -Name $modulePath -Force
            Start-ExamPreparation -ConfigPath $configPath -LogPath $logPath
        }
        catch {
            Write-Error "Errore durante l'esecuzione della preparazione: $($_.Exception.Message)"
        }
    }
    "Restore" {
        Ensure-Admin
        Write-Host "Avvio modalità Ripristino..." -ForegroundColor Green
        try {
            Import-Module -Name $modulePath -Force
            Start-ExamRestore -ConfigPath $configPath -LogPath $logPath
        }
        catch {
            Write-Error "Errore durante l'esecuzione del ripristino: $($_.Exception.Message)"
        }
    }
    "Report" {
        # La generazione del report non richiede privilegi elevati
        Write-Host "Avvio generazione Report..." -ForegroundColor Green
        try {
            Import-Module -Name $modulePath -Force
            New-ExamPrepReport -ReportPath $reportPath
        }
        catch {
            Write-Error "Errore durante la generazione del report: $($_.Exception.Message)"
        }
    }
}

Write-Host "Operazione '$Mode' completata."
if ($Host.UI.RawUI.KeyAvailable -or $Host.Name -eq 'ConsoleHost') {
    Write-Host "Premere un tasto per uscire..."
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        # Ignora errori se non è possibile leggere l'input (es. redirect o non-interattivo)
    }
}