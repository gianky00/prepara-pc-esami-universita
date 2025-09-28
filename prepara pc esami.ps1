<#
.SYNOPSIS
Script per preparare un PC Windows 10/11 per un esame universitario con proctoring.
Ottimizza le prestazioni, chiude le applicazioni non consentite e crea un ambiente senza distrazioni.
Include una modalità di ripristino per annullare tutte le modifiche.

.DESCRIPTION
Lo script opera in due modalità: Preparazione e Ripristino.
- Modalità Preparazione: da eseguire prima dell'esame.
  - Richiede i permessi di amministratore.
  - Salva lo stato corrente del sistema (es. schema energetico).
  - Chiede conferma all'utente prima di procedere.
  - Termina i processi non necessari (configurabili).
  - Imposta le prestazioni al massimo e pulisce i file temporanei.
  - Ferma servizi di background non essenziali.
  - Attiva la modalità "Assistente Notifiche" e disabilita la Game Bar.
- Modalità Ripristino: da eseguire dopo l'esame.
  - Ripristina lo schema energetico originale.
  - Riavvia i servizi interrotti.
  - Disattiva l'Assistente Notifiche e riabilita la Game Bar.

.PARAMETER Modalita
Specifica se eseguire lo script in modalità 'Preparazione' o 'Ripristino'.
Il valore predefinito è 'Preparazione'.

.EXAMPLE
# Per eseguire la preparazione per l'esame (verrà richiesta elevazione dei privilegi)
.\PreparazioneEsame.ps1 -Modalita Preparazione

# Per eseguire il ripristino dopo l'esame (verrà richiesta elevazione dei privilegi)
.\PreparazioneEsame.ps1 -Modalita Ripristino

.NOTES
Autore: Gemini
Versione: 1.0
Assicurarsi di eseguire lo script da una console PowerShell con il comando:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
#>

#--- INIZIO CONFIGURAZIONE UTENTE ---
# In questa sezione puoi personalizzare le liste di applicazioni e servizi.
# Aggiungi o rimuovi i nomi dei processi SENZA l'estensione ".exe".

# Lista dei processi da terminare forzatamente.
$processiDaTerminare = @(
    # Software di Comunicazione
    "Discord",
    "Telegram",
    "Skype",
    "Slack",
    "Zoom",
    "msedge",
    # Software di Screen Recording/Sharing
    "obs64",
    "obs32",
    "AnyDesk",
    "TeamViewer",
    # Overlays e Gaming
    "Steam",
    "GameBar", # Processo della Game Bar
    # Altri software non essenziali
    "Spotify"
)

# Lista delle applicazioni CONSENTITE (es. il browser dell'esame o l'app di proctoring).
# Queste applicazioni non verranno terminate anche se presenti nella lista sopra.
$applicazioniConsentite = @(
    "chrome",
    "Ecampus proctor" # Nome ipotetico, da verificare e correggere se necessario
)

# Lista dei servizi di Windows da interrompere temporaneamente.
$serviziDaGestire = @(
    "SysMain",      # Superfetch
    "WSearch",      # Windows Search
    "BITS"          # Servizio trasferimento intelligente in background
)
#--- FINE CONFIGURAZIONE UTENTE ---

# Parametro per scegliere la modalità di esecuzione
param (
    [ValidateSet("Preparazione", "Ripristino")]
    [string]$Modalita = "Preparazione"
)

# Percorso del file di backup per il ripristino
$fileBackup = Join-Path $env:TEMP "exam_prep_state.json"

# Funzione per richiedere i privilegi di amministratore
function Richiedi-Admin {
    if (-not ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Richiesta di privilegi di amministratore..."
        Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -File `"$PSCommandPath`" -Modalita $Modalita"
        exit
    }
}

# Funzione per la modalità PREPARAZIONE ESAME
function Avvia-Preparazione {
    Write-Host "--- MODALITÀ PREPARAZIONE ESAME ---" -ForegroundColor Yellow

    # 1. Backup dello stato corrente
    Write-Host "`n[1/6] Salvataggio dello stato corrente del sistema..." -ForegroundColor Cyan
    try {
        $schemaEnergeticoAttuale = (powercfg /getactivescheme).Split(' ')[3]
        $gameBarEnabled = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue
        $focusAssistLevel = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\QuietHours" -Name "QuietHoursProfile" -ErrorAction SilentlyContinue

        $statoDaSalvare = @{
            SchemaEnergetico = $schemaEnergeticoAttuale
            GameBarEnabled   = if ($null -eq $gameBarEnabled) { 1 } else { $gameBarEnabled } # Default a 1 (attivo) se non esiste
            FocusAssistLevel = if ($null -eq $focusAssistLevel) { 0 } else { $focusAssistLevel } # Default a 0 (disattivo) se non esiste
        }
        $statoDaSalvare | ConvertTo-Json | Out-File -FilePath $fileBackup -Encoding UTF8
        Write-Host "Stato salvato con successo in `"$fileBackup`"." -ForegroundColor Green
    }
    catch {
        Write-Error "Impossibile salvare lo stato del sistema. Errore: $($_.Exception.Message)"
        exit 1
    }

    # 2. Conferma Utente
    Write-Host "`n[2/6] Riepilogo delle azioni che verranno eseguite:" -ForegroundColor Cyan
    $processiTrovati = Get-Process -Name $processiDaTerminare -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -notin $applicazioniConsentite } | Select-Object -ExpandProperty ProcessName -Unique
    if ($processiTrovati) {
        Write-Host " - Terminerò i seguenti processi: $($processiTrovati -join ', ')"
    }
    else {
        Write-Host " - Nessun processo non consentito da terminare è attualmente in esecuzione."
    }
    Write-Host " - Imposterò lo schema energetico su 'Prestazioni elevate'."
    Write-Host " - Disattiverò temporaneamente i servizi: $($serviziDaGestire -join ', ')"
    Write-Host " - Pulirò le cartelle dei file temporanei."
    Write-Host " - Attiverò l'Assistente Notifiche e disabiliterò la Game Bar."

    $conferma = Read-Host "`nContinuare? [S/N]"
    if ($conferma -ne 'S') {
        Write-Host "Operazione annullata dall'utente." -ForegroundColor Yellow
        exit
    }

    # 3. Terminazione Processi
    Write-Host "`n[3/6] Terminazione dei processi non consentiti..." -ForegroundColor Cyan
    if ($processiTrovati) {
        foreach ($processo in $processiTrovati) {
            Get-Process -Name $processo | Stop-Process -Force
            Write-Host " - Processo '$processo' terminato." -ForegroundColor Green
        }
    }
    else {
        Write-Host "Nessun processo da terminare."
    }

    # 4. Ottimizzazione Prestazioni
    Write-Host "`n[4/6] Ottimizzazione delle prestazioni..." -ForegroundColor Cyan
    # Schema energetico
    $guidPrestazioniElevate = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    powercfg /setactive $guidPrestazioniElevate
    Write-Host " - Schema energetico impostato su 'Prestazioni elevate'." -ForegroundColor Green

    # Pulizia file temporanei
    $cartelleTemp = @("$env:TEMP", "$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch")
    foreach ($cartella in $cartelleTemp) {
        if (Test-Path $cartella) {
            Remove-Item -Path "$cartella\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host " - Cartella '$cartella' pulita." -ForegroundColor Green
        }
    }

    # Interruzione servizi
    foreach ($servizio in $serviziDaGestire) {
        if (Get-Service -Name $servizio -ErrorAction SilentlyContinue) {
            Stop-Service -Name $servizio -Force -ErrorAction SilentlyContinue
            Write-Host " - Servizio '$servizio' interrotto." -ForegroundColor Green
        }
    }

    # 5. Ambiente Senza Distrazioni
    Write-Host "`n[5/6] Creazione di un ambiente senza distrazioni..." -ForegroundColor Cyan
    # Assistente Notifiche (Focus Assist) su "Solo Sveglie"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\QuietHours" -Name "QuietHoursProfile" -Value 2 -Force
    Write-Host " - Assistente Notifiche impostato su 'Solo sveglie'." -ForegroundColor Green
    
    # Disattivazione Game Bar
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Force
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $registryPath -Name "AllowGameDVR" -Value 0 -Force
    Write-Host " - Xbox Game Bar disabilitata." -ForegroundColor Green

    # 6. Report Finale
    Write-Host "`n[6/6] Operazione completata." -ForegroundColor Cyan
    Write-Host "`nPC pronto per l'esame. In bocca al lupo!" -ForegroundColor Magenta
}

# Funzione per la modalità RIPRISTINO POST-ESAME
function Avvia-Ripristino {
    Write-Host "--- MODALITÀ RIPRISTINO POST-ESAME ---" -ForegroundColor Yellow

    if (-not (Test-Path $fileBackup)) {
        Write-Error "File di backup '$fileBackup' non trovato. Impossibile ripristinare. Esegui prima la modalità Preparazione."
        exit 1
    }

    Write-Host "`n[1/4] Lettura dello stato da ripristinare..." -ForegroundColor Cyan
    $statoDaRipristinare = Get-Content -Path $fileBackup | ConvertFrom-Json
    
    # 1. Ripristino Schema Energetico
    Write-Host "`n[2/4] Ripristino delle impostazioni di sistema..." -ForegroundColor Cyan
    powercfg /setactive $statoDaRipristinare.SchemaEnergetico
    Write-Host " - Schema energetico ripristinato." -ForegroundColor Green

    # 2. Ripristino Impostazioni Ambiente
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\QuietHours" -Name "QuietHoursProfile" -Value $statoDaRipristinare.FocusAssistLevel -Force
    Write-Host " - Assistente Notifiche ripristinato." -ForegroundColor Green
    
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value $statoDaRipristinare.GameBarEnabled -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 1 -Force
    Write-Host " - Xbox Game Bar riabilitata." -ForegroundColor Green
    
    # 3. Riattivazione Servizi
    Write-Host "`n[3/4] Riavvio dei servizi..." -ForegroundColor Cyan
    foreach ($servizio in $serviziDaGestire) {
         if (Get-Service -Name $servizio -ErrorAction SilentlyContinue) {
            Start-Service -Name $servizio -ErrorAction SilentlyContinue
            Write-Host " - Servizio '$servizio' riavviato." -ForegroundColor Green
        }
    }

    # 4. Pulizia e Report Finale
    Write-Host "`n[4/4] Pulizia e completamento..." -ForegroundColor Cyan
    Remove-Item -Path $fileBackup -Force
    Write-Host " - File di backup rimosso." -ForegroundColor Green
    
    Write-Host "`nSistema ripristinato alle impostazioni originali. Ben fatto!" -ForegroundColor Magenta
}

# --- ESECUZIONE SCRIPT ---
# 1. Richiede i permessi di amministratore se non li ha
Richiedi-Admin

# 2. Esegue la modalità selezionata
if ($Modalita -eq "Preparazione") {
    Avvia-Preparazione
}
elseif ($Modalita -eq "Ripristino") {
    Avvia-Ripristino
}
