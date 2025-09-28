<#
.SYNOPSIS
    Prepara un PC Windows 10/11 per un esame con proctoring e ripristina lo stato originale al termine.

.DESCRIPTION
    Questo script ottimizza le prestazioni, elimina le distrazioni e chiude le applicazioni non consentite
    per garantire un ambiente di esame stabile e conforme. Opera in due modalità:
    - Preparazione: Da eseguire prima dell'esame.
    - Ripristino: Da eseguire dopo l'esame per annullare tutte le modifiche.

.PARAMETER Mode
    Specifica la modalità operativa. I valori accettati sono 'Preparazione' o 'Ripristino'.

.EXAMPLE
    # Per preparare il PC per l'esame (richiede privilegi di amministratore):
    .\Exam-Prep.ps1 -Mode Preparazione

.EXAMPLE
    # Per ripristinare il PC dopo l'esame:
    .\Exam-Prep.ps1 -Mode Ripristino

.NOTES
    Autore: Jules, assistente AI
    Versione: 2.0
    Assicurarsi di eseguire lo script da una console PowerShell con privilegi di amministratore.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Scegli la modalità: 'Preparazione' o 'Ripristino'")]
    [ValidateSet('Preparazione', 'Ripristino')]
    [string]$Mode
)

#--------------------------------------------------------------------------------#
#--- INIZIO AREA DI PERSONALIZZAZIONE ---
# In questa sezione è possibile personalizzare le liste di applicazioni e servizi.
#--------------------------------------------------------------------------------#

# Lista dei processi da terminare (nomi degli eseguibili).
# Chrome.exe è stato rimosso come richiesto. Aggiungere qui altri processi se necessario.
$processesToKill = @(
    # Software di Comunicazione
    "Discord.exe", "Telegram.exe", "Skype.exe", "Slack.exe", "Zoom.exe", "msedge.exe",
    # Software di Screen Recording/Sharing
    "obs64.exe", "obs32.exe", "AnyDesk.exe", "TeamViewer.exe",
    # Overlays e Gaming
    "Steam.exe", "GameBar.exe", "GameBarPresenceWriter.exe",
    # Altri software non essenziali
    "Spotify.exe", "OneDrive.exe"
)

# Lista delle applicazioni CONSENTITE (es. il browser dell'esame o l'app di proctoring).
# Questi processi non verranno terminati. 'chrome' è già escluso dalla lista sopra.
$allowedApplications = @(
    "Ecampus proctor.exe" # Nome ipotetico, da correggere con il nome esatto dell'eseguibile.
)

# Lista dei servizi di Windows da interrompere temporaneamente.
$servicesToManage = @(
    "SysMain",      # Superfetch: Ottimizza l'avvio delle app, ma può usare risorse in background.
    "WSearch",      # Windows Search: Indicizza i file, non necessario durante un esame.
    "BITS"          # Servizio trasferimento intelligente in background: Usato per aggiornamenti, può consumare banda.
)

#--------------------------------------------------------------------------------#
#--- FINE AREA DI PERSONALIZZAZIONE ---
#--------------------------------------------------------------------------------#


# Funzione per verificare e richiedere i privilegi di amministratore.
# Deve essere eseguita all'inizio per garantire che lo script abbia i permessi necessari.
function Request-AdminPrivileges {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Privilegi di amministratore richiesti. Riavvio dello script in corso..."
        Write-Host "Se richiesto dal Controllo Account Utente (UAC), concedere l'autorizzazione." -ForegroundColor Yellow
        Start-Sleep -Seconds 2

        # Riavvia lo script corrente con il verbo 'RunAs' per elevare i privilegi.
        # Viene passata la modalità selezionata per mantenere il contesto.
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode" -ErrorAction Stop
        }
        catch {
            Write-Error "Impossibile riavviare lo script con privilegi di amministratore. Errore: $($_.Exception.Message)"
            Write-Error "Si prega di eseguire manualmente lo script da un terminale avviato come Amministratore."
        }

        # Esce dallo script corrente in attesa che quello nuovo (con privilegi) parta.
        exit
    }
}

# Funzione per la modalità PREPARAZIONE ESAME
function Start-Preparation {
    Write-Host "--- MODALITÀ PREPARAZIONE ESAME ATTIVATA ---" -ForegroundColor Cyan

    # 1. Backup dello stato corrente
    Write-Host "`n[1/6] Backup della configurazione di sistema in corso..." -ForegroundColor Yellow
    $backupFile = Join-Path $env:TEMP "ExamPrepBackup.json"
    $backupData = @{}

    try {
        # Backup Schema Energetico: Salva il GUID dello schema attualmente attivo.
        $activeScheme = powercfg /getactivescheme
        $backupData.PowerScheme = ($activeScheme -split ' ')[3]
        Write-Host "   - Schema energetico salvato: $($activeScheme -split '`(')[1].Trim(')')"

        # Backup Assistente Notifiche (Focus Assist)
        $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"
        $backupData.FocusAssistProfile = (Get-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -ErrorAction SilentlyContinue).QuietHoursProfile

        # Backup Game Bar
        $gameBarAllowKey = "HKCU:\Software\Microsoft\GameBar"
        $gameBarPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        $backupData.GameBarAllowed = (Get-ItemProperty -Path $gameBarAllowKey -Name "AllowGameBar" -ErrorAction SilentlyContinue).AllowGameBar
        $backupData.GameBarPolicy = (Get-ItemProperty -Path $gameBarPolicyKey -Name "AllowGameDVR" -ErrorAction SilentlyContinue).AllowGameDVR

        $backupData | ConvertTo-Json | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Host "   - Backup completato con successo in `"$backupFile`"." -ForegroundColor Green
    }
    catch {
        Write-Error "Errore durante il backup della configurazione. Operazione interrotta. Dettagli: $($_.Exception.Message)"
        exit
    }

    # 2. Conferma Utente
    # Calcola la lista finale di processi da terminare
    $finalProcessesToKill = $processesToKill | Where-Object { $_ -notin $allowedApplications }

    Write-Host "`n[2/6] Riepilogo delle azioni:" -ForegroundColor Yellow
    Write-Host "   - Terminerò i seguenti processi: $($finalProcessesToKill -join ', ')"
    Write-Host "   - Imposterò lo schema energetico su 'Prestazioni elevate'."
    Write-Host "   - Disattiverò le notifiche e la Game Bar."
    Write-Host "   - Interromperò i seguenti servizi: $($servicesToManage -join ', ')"
    Write-Host "   - Pulirò i file temporanei."

    $confirmation = Read-Host "Procedere con la preparazione? [S/N]"
    if ($confirmation -ne 'S') {
        Write-Error "Operazione annullata dall'utente."
        Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue
        exit
    }

    # 3. Terminazione Processi
    Write-Host "`n[3/6] Terminazione dei processi non necessari..." -ForegroundColor Yellow
    foreach ($process in $finalProcessesToKill) {
        $procName = $process.Replace(".exe", "")
        if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
            Stop-Process -Name $procName -Force
            Write-Host "   - Terminato: $process"
        }
    }
    Write-Host "   - Processi terminati." -ForegroundColor Green

    # 4. Ottimizzazione Prestazioni
    Write-Host "`n[4/6] Ottimizzazione delle prestazioni..." -ForegroundColor Yellow

    # Imposta "Prestazioni Elevate" dinamicamente
    $highPerfScheme = powercfg /list | Where-Object { $_ -like "*Prestazioni elevate*" }
    if ($highPerfScheme) {
        $highPerfGuid = ($highPerfScheme -split ' ')[3]
        powercfg /setactive $highPerfGuid
        Write-Host "   - Schema energetico impostato su 'Prestazioni elevate'."
    } else {
        Write-Warning "   - Schema 'Prestazioni elevate' non trovato. L'impostazione energetica non è stata modificata."
    }

    # Interrompi Servizi
    foreach ($service in $servicesToManage) {
        $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($serviceObj -and $serviceObj.Status -eq 'Running') {
            Stop-Service -Name $service -Force
            Write-Host "   - Servizio interrotto: $service"
        }
    }

    # Pulizia File Temporanei
    Write-Host "   - Pulizia cartelle temporanee..."
    $tempPaths = @("$env:TEMP", "$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            # Rimuove il contenuto delle cartelle, non le cartelle stesse.
            Remove-Item -Path (Join-Path $path "*") -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "     - Pulita: $path"
        }
    }
    Write-Host "   - Ottimizzazione completata." -ForegroundColor Green

    # 5. Ambiente Senza Distrazioni
    Write-Host "`n[5/6] Creazione ambiente senza distrazioni..." -ForegroundColor Yellow

    # Attiva Assistente Notifiche (Solo Sveglie)
    # 0 = Off, 1 = Solo priorità, 2 = Solo sveglie
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" -Name "QuietHoursProfile" -Value 2 -Force
    Write-Host "   - Notifiche disattivate (modalità 'Solo Sveglie')."

    # Disabilita Game Bar (metodo utente e policy di sistema per massima efficacia)
    if (-not (Test-Path $gameBarAllowKey)) { New-Item -Path $gameBarAllowKey -Force | Out-Null }
    Set-ItemProperty -Path $gameBarAllowKey -Name "AllowGameBar" -Value 0 -Type DWord -Force

    if (-not (Test-Path $gameBarPolicyKey)) { New-Item -Path $gameBarPolicyKey -Force | Out-Null }
    Set-ItemProperty -Path $gameBarPolicyKey -Name "AllowGameDVR" -Value 0 -Type DWord -Force
    Write-Host "   - Xbox Game Bar disabilitata."
    Write-Host "   - Ambiente pronto." -ForegroundColor Green

    # 6. Report Finale
    Write-Host "`n[6/6] PREPARAZIONE COMPLETATA" -ForegroundColor Green
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Il PC è pronto per l'esame. In bocca al lupo!" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
}

# Funzione per la modalità RIPRISTINO POST-ESAME
function Start-Restore {
    Write-Host "--- MODALITÀ RIPRISTINO POST-ESAME ATTIVATA ---" -ForegroundColor Cyan
    $backupFile = Join-Path $env:TEMP "ExamPrepBackup.json"

    if (-not (Test-Path $backupFile)) {
        Write-Error "File di backup non trovato in `"$backupFile`". Impossibile ripristinare."
        Write-Warning "Lo script tenterà un ripristino con valori predefiniti, ma potrebbe non essere completo."
    }

    $backupData = Get-Content -Path $backupFile | ConvertFrom-Json

    # 1. Ripristino Impostazioni di Sistema
    Write-Host "`n[1/3] Ripristino delle impostazioni di sistema..." -ForegroundColor Yellow
    try {
        # Ripristino Schema Energetico
        if ($backupData.PowerScheme) {
            powercfg /setactive $backupData.PowerScheme
            Write-Host "   - Schema energetico ripristinato."
        } else {
            # Fallback allo schema "Bilanciato" se il backup non esiste
            powercfg /setactive "381b4222-f694-41f0-9685-ff5bb260df2e"
            Write-Warning "   - Schema energetico ripristinato su 'Bilanciato' (predefinito)."
        }

        # Ripristino Assistente Notifiche
        $originalProfile = if ($null -ne $backupData.FocusAssistProfile) { $backupData.FocusAssistProfile } else { 0 } # Default a 0 (Off)
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" -Name "QuietHoursProfile" -Value $originalProfile -Force
        Write-Host "   - Assistente notifiche ripristinato."

        # Ripristino Game Bar
        $originalAllowValue = if ($null -ne $backupData.GameBarAllowed) { $backupData.GameBarAllowed } else { 1 } # Default a 1 (On)
        $originalPolicyValue = if ($null -ne $backupData.GameBarPolicy) { $backupData.GameBarPolicy } else { 1 } # Default a 1 (On)
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowGameBar" -Value $originalAllowValue -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value $originalPolicyValue -Type DWord -Force
        Write-Host "   - Xbox Game Bar riabilitata."
        Write-Host "   - Impostazioni di sistema ripristinate." -ForegroundColor Green
    }
    catch {
        Write-Error "Errore durante il ripristino delle impostazioni di sistema. Dettagli: $($_.Exception.Message)"
    }

    # 2. Riattivazione Servizi
    Write-Host "`n[2/3] Riavvio dei servizi di background..." -ForegroundColor Yellow
    foreach ($service in $servicesToManage) {
        $serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($serviceObj -and $serviceObj.Status -ne 'Running') {
            Start-Service -Name $service
            Write-Host "   - Servizio avviato: $service"
        }
    }
    Write-Host "   - Servizi riavviati." -ForegroundColor Green

    # 3. Pulizia e Report Finale
    Write-Host "`n[3/3] Pulizia e completamento..." -ForegroundColor Yellow
    if (Test-Path $backupFile) {
        Remove-Item -Path $backupFile -Force
        Write-Host "   - File di backup rimosso."
    }

    Write-Host "`nRIPRISTINO COMPLETATO" -ForegroundColor Green
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Il sistema è stato ripristinato. Ben fatto!" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
}


# --- ESECUZIONE DELLO SCRIPT ---

# 1. Controlla e richiede i privilegi di amministratore all'avvio.
# Questo è necessario per quasi tutte le operazioni dello script (powercfg, servizi, registro HKLM).
Request-AdminPrivileges

# 2. Esegue la modalità selezionata dall'utente.
if ($Mode -eq "Preparazione") {
    Start-Preparation
}
elseif ($Mode -eq "Ripristino") {
    Start-Restore
}