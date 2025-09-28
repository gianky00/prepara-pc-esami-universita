<#
.SYNOPSIS
    Prepara un PC Windows 10/11 per un esame con proctoring e ripristina lo stato originale al termine.
.DESCRIPTION
    Questo script ottimizza le prestazioni, elimina le distrazioni e chiude le applicazioni non consentite
    per garantire un ambiente di esame stabile e conforme. Include un sistema di logging dettagliato.
.NOTES
    Autore: Jules, assistente AI
    Versione: 3.0
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Scegli la modalità: 'Preparazione' o 'Ripristino'")]
    [ValidateSet('Preparazione', 'Ripristino')]
    [string]$Mode
)

#--------------------------------------------------------------------------------#
#--- INIZIO CONFIGURAZIONE GLOBALE ---
#--------------------------------------------------------------------------------#

# Percorso del file di log, creato nella stessa cartella dello script.
# $PSScriptRoot è una variabile automatica che contiene la directory dello script in esecuzione.
$logFile = Join-Path $PSScriptRoot "Exam-Prep.log"

# --- INIZIO AREA DI PERSONALIZZAZIONE ---

$processesToKill = @(
    "Discord.exe", "Telegram.exe", "Skype.exe", "Slack.exe", "Zoom.exe", "msedge.exe",
    "obs64.exe", "obs32.exe", "AnyDesk.exe", "TeamViewer.exe", "Steam.exe",
    "GameBar.exe", "GameBarPresenceWriter.exe", "Spotify.exe", "OneDrive.exe"
)
$allowedApplications = @("Ecampus proctor.exe")
$servicesToManage = @("SysMain", "WSearch", "BITS")

# --- FINE AREA DI PERSONALIZZAZIONE ---

#--------------------------------------------------------------------------------#
#--- FUNZIONI DELLO SCRIPT ---
#--------------------------------------------------------------------------------#

# Funzione di logging robusta che scrive sia su file che a console con colori.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "TITLE")][string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] - $Message"
    Add-Content -Path $logFile -Value $logEntry

    $color = switch ($Level) {
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "TITLE"   { "Cyan" }
        default   { "White" }
    }
    # Per i titoli, non mostriamo il timestamp a console per pulizia.
    if ($Level -eq "TITLE") { Write-Host $Message -ForegroundColor $color }
    else { Write-Host $logEntry -ForegroundColor $color }
}

function Request-AdminPrivileges {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log -Message "Privilegi di amministratore richiesti. Riavvio dello script in corso..." -Level WARN
        Start-Sleep -Seconds 1
        try {
            $arguments = "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-Mode", $Mode
            Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -ErrorAction Stop
        } catch {
            Write-Log -Message "Impossibile riavviare con privilegi elevati. Eseguire manualmente lo script come Amministratore." -Level ERROR
        }
        exit
    }
}

function Start-Preparation {
    Write-Log -Message "--- MODALITÀ PREPARAZIONE ESAME ATTIVATA ---" -Level TITLE
    $backupFile = Join-Path $env:TEMP "ExamPrepBackup.json"
    $backupData = @{}

    # 1. Backup
    Write-Log -Message "[1/6] Backup della configurazione di sistema..." -Level INFO
    try {
        $activeSchemeOutput = powercfg /getactivescheme
        $guidMatch = $activeSchemeOutput | Select-String -Pattern '[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}'
        if ($guidMatch) {
            $backupData.PowerScheme = $guidMatch.Matches[0].Value
            $nameMatch = $activeSchemeOutput | Select-String -Pattern '\((.*)\)'
            $schemeName = if ($nameMatch) { $nameMatch.Matches[0].Groups[1].Value } else { ($activeSchemeOutput -split ':')[1].Trim() }
            Write-Log -Message "   - Schema energetico '$schemeName' salvato." -Level SUCCESS
        } else {
            throw "Impossibile trovare il GUID dello schema energetico attivo."
        }
        $backupData.FocusAssistProfile = (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" -Name "QuietHoursProfile" -ErrorAction SilentlyContinue).QuietHoursProfile
        $backupData | ConvertTo-Json | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Log -Message "   - Backup completato in `"$backupFile`"." -Level SUCCESS
    } catch {
        Write-Log -Message "Errore durante il backup. Operazione interrotta. Dettagli: $($_.Exception.Message)" -Level ERROR
        exit
    }

    # 2. Conferma Utente
    $finalProcessesToKill = $processesToKill | Where-Object { $_ -notin $allowedApplications }
    Write-Log -Message "[2/6] Riepilogo azioni:" -Level INFO
    # ... (messaggi di riepilogo)
    $confirmation = Read-Host "Procedere con la preparazione? [S/N]"
    if ($confirmation -ne 'S') {
        Write-Log -Message "Operazione annullata dall'utente." -Level WARN
        Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue
        exit
    }
    Write-Log -Message "Conferma ricevuta dall'utente." -Level INFO

    # 3. Terminazione Processi
    Write-Log -Message "[3/6] Terminazione processi..." -Level INFO
    foreach ($process in $finalProcessesToKill) {
        $procName = $process.Replace(".exe", "")
        if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
            Stop-Process -Name $procName -Force
            Write-Log -Message "   - Terminato: $process" -Level SUCCESS
        }
    }

    # 4. Ottimizzazione Prestazioni
    Write-Log -Message "[4/6] Ottimizzazione prestazioni..." -Level INFO
    $highPerfGuid = "8c5e7fda-e8bf-4a96-9a8f-a307e2250669"
    try {
        powercfg /setactive $highPerfGuid
        Write-Log -Message "   - Schema energetico impostato su 'Prestazioni elevate'." -Level SUCCESS
    } catch {
        Write-Log -Message "   - Impossibile impostare lo schema 'Prestazioni elevate'." -Level WARN
    }
    foreach ($service in $servicesToManage) {
        $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($serviceObj) {
            if ($serviceObj.Status -eq 'Running') {
                Stop-Service -Name $service -Force
                Write-Log -Message "   - Servizio interrotto: $service" -Level SUCCESS
            } else {
                Write-Log -Message "   - Servizio già fermo: $service" -Level INFO
            }
        }
    }
    # Pulizia File Temporanei
    # ...

    # 5. Ambiente Senza Distrazioni
    Write-Log -Message "[5/6] Creazione ambiente senza distrazioni..." -Level INFO
    $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"
    if (-not (Test-Path $quietHoursKey)) {
        New-Item -Path $quietHoursKey -Force | Out-Null
        Write-Log -Message "   - Creato percorso registro per QuietHours." -Level INFO
    }
    Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value 2 -Force
    Write-Log -Message "   - Notifiche disattivate (Solo Sveglie)." -Level SUCCESS
    # ... (Game Bar)

    # 6. Report Finale
    Write-Log -Message "[6/6] PREPARAZIONE COMPLETATA. In bocca al lupo!" -Level TITLE
}

function Start-Restore {
    Write-Log -Message "--- MODALITÀ RIPRISTINO POST-ESAME ATTIVATA ---" -Level TITLE
    $backupFile = Join-Path $env:TEMP "ExamPrepBackup.json"
    if (-not (Test-Path $backupFile)) {
        Write-Log -Message "File di backup non trovato. Impossibile ripristinare." -Level ERROR
        return
    }
    $backupData = Get-Content -Path $backupFile | ConvertFrom-Json

    # 1. Ripristino Impostazioni
    Write-Log -Message "[1/3] Ripristino delle impostazioni di sistema..." -Level INFO
    try {
        if ($backupData.PowerScheme) {
            powercfg /setactive $backupData.PowerScheme
            Write-Log -Message "   - Schema energetico ripristinato." -Level SUCCESS
        } else {
            powercfg /setactive "381b4222-f694-41f0-9685-ff5bb260df2e"
            Write-Log -Message "   - Schema energetico impostato su 'Bilanciato' (predefinito)." -Level WARN
        }
        $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"
        $originalProfile = if ($null -ne $backupData.FocusAssistProfile) { $backupData.FocusAssistProfile } else { 0 }
        if (-not (Test-Path $quietHoursKey)) { New-Item -Path $quietHoursKey -Force | Out-Null }
        Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value $originalProfile -Force
        Write-Log -Message "   - Assistente notifiche ripristinato." -Level SUCCESS
        # ... (Game Bar)
    } catch {
        Write-Log -Message "Errore durante il ripristino. Dettagli: $($_.Exception.Message)" -Level ERROR
    }

    # 2. Riattivazione Servizi
    Write-Log -Message "[2/3] Riavvio dei servizi..." -Level INFO
    foreach ($service in $servicesToManage) {
        $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($serviceObj -and $serviceObj.Status -ne 'Running') {
            Start-Service -Name $service
            Write-Log -Message "   - Servizio avviato: $service" -Level SUCCESS
        }
    }

    # 3. Pulizia e Report Finale
    Write-Log -Message "[3/3] Pulizia e completamento..." -Level INFO
    Remove-Item -Path $backupFile -Force
    Write-Log -Message "   - File di backup rimosso." -Level INFO
    Write-Log -Message "RIPRISTINO COMPLETATO. Ben fatto!" -Level TITLE
}


# --- ESECUZIONE DELLO SCRIPT ---
# Pulisce il log precedente se esiste ed è più grande di 1MB per evitare che cresca indefinitamente.
if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 1MB)) {
    Clear-Content -Path $logFile
}

Write-Log -Message "Avvio script in modalità '$Mode'." -Level INFO
Request-AdminPrivileges

if ($Mode -eq "Preparazione") {
    Start-Preparation
} elseif ($Mode -eq "Ripristino") {
    Start-Restore
}
Write-Log -Message "Esecuzione script terminata." -Level INFO