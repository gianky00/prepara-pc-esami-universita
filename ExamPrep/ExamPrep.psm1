# --- INIZIO MODULO POWERSHELL ExamPrep ---
# Versione 4.1.0: Logica completa implementata.

#region Funzioni Private (Interne al Modulo)

# Funzione di logging robusta. Non viene esportata, ma usata dalle funzioni pubbliche.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "TITLE", "VERBOSE")][string]$Level = "INFO",
        [string]$LogPath
    )

    # Scrittura su file di log
    if ($LogPath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] - $Message"
        try {
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Warning "Impossibile scrivere nel file di log in '$LogPath'. Errore: $($_.Exception.Message)"
        }
    }

    # Output a console
    if ($Level -eq "VERBOSE") {
        Write-Verbose $Message
        return
    }

    $color = switch ($Level) {
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "TITLE"   { "Cyan" }
        default   { "White" }
    }

    $consoleMessage = if ($Level -in "INFO", "WARN", "ERROR", "SUCCESS") { "[$($Level.PadRight(7))] $Message" } else { $Message }
    Write-Host $consoleMessage -ForegroundColor $color
}

# Funzione per caricare la configurazione da JSON
function Get-ExamPrepConfig {
    param([string]$ConfigPath)
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "File di configurazione non trovato in '$ConfigPath'."
        }
        return Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    } catch {
        throw "Errore durante la lettura o l'analisi del file di configurazione: $($_.Exception.Message)"
    }
}

# Funzione per garantire che un percorso di registro esista
function Test-And-Create-RegistryPath {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            return $true
        } catch {
            throw "Impossibile creare il percorso di registro '$Path'. Errore: $($_.Exception.Message)"
        }
    }
    return $false
}

#endregion

#region Funzioni Pubbliche (Esportate dal Modulo)

function Start-ExamPreparation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$LogPath
    )

    Write-Log -Level TITLE -Message "--- MODALITÀ PREPARAZIONE ESAME ATTIVATA ---" -LogPath $LogPath

    try {
        $config = Get-ExamPrepConfig -ConfigPath $ConfigPath
    } catch {
        Write-Log -Level ERROR -Message $_.Exception.Message -LogPath $LogPath
        return
    }

    # 1. Backup
    $backupFile = Join-Path $env:TEMP "ExamPrepBackup.json"
    $backupData = @{ Services = @{} }
    Write-Log -Level INFO -Message "[1/7] Backup della configurazione di sistema..." -LogPath $LogPath
    try {
        $activeSchemeOutput = powercfg /getactivescheme
        $guidMatch = $activeSchemeOutput | Select-String -Pattern '[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}'
        if ($guidMatch) {
            $backupData.PowerScheme = $guidMatch.Matches[0].Value
            $nameMatch = $activeSchemeOutput | Select-String -Pattern '\((.*)\)'
            $schemeName = if ($nameMatch) { $nameMatch.Matches[0].Groups[1].Value } else { ($activeSchemeOutput -split ':')[1].Trim() }
            Write-Log -Level VERBOSE -Message "Schema energetico attivo: '$schemeName' ($($backupData.PowerScheme))" -LogPath $LogPath
        } else { throw "Impossibile trovare il GUID dello schema energetico attivo." }

        $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"
        $backupData.FocusAssistProfile = (Get-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -ErrorAction SilentlyContinue).QuietHoursProfile

        $gameBarAllowKey = "HKCU:\Software\Microsoft\GameBar"
        $gameBarPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        $backupData.GameBarAllowed = (Get-ItemProperty -Path $gameBarAllowKey -Name "AllowGameBar" -ErrorAction SilentlyContinue).AllowGameBar
        $backupData.GameBarPolicy = (Get-ItemProperty -Path $gameBarPolicyKey -Name "AllowGameDVR" -ErrorAction SilentlyContinue).AllowGameDVR

        foreach ($serviceName in $config.ServicesToManage) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) { $backupData.Services[$serviceName] = $service.Status }
        }

        $backupData | ConvertTo-Json -Depth 3 | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Log -Level SUCCESS -Message "   - Backup completato in `"$backupFile`"." -LogPath $LogPath
    } catch {
        Write-Log -Level ERROR -Message "Errore durante il backup. Operazione interrotta. Dettagli: $($_.Exception.Message)" -LogPath $LogPath
        return
    }

    # 2. Conferma Utente
    if (-not $PSCmdlet.ShouldProcess("il sistema per la preparazione all'esame", "Sei sicuro di voler procedere?", "Conferma")) {
        Write-Log -Level WARN -Message "Operazione annullata dall'utente." -LogPath $LogPath
        Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue
        return
    }
    Write-Log -Level INFO -Message "Conferma ricevuta, avvio delle operazioni..." -LogPath $LogPath

    # 3. Terminazione Processi
    Write-Log -Level INFO -Message "[3/7] Terminazione processi non consentiti..." -LogPath $LogPath
    $finalProcessesToKill = $config.ProcessesToKill | Where-Object { $_ -notin $config.AllowedApplications }
    foreach ($process in $finalProcessesToKill) {
        $procName = $process.Replace(".exe", "")
        if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
            Stop-Process -Name $procName -Force
            Write-Log -Level SUCCESS -Message "   - Terminato: $process" -LogPath $LogPath
        }
    }

    # 4. Ottimizzazione Prestazioni
    Write-Log -Level INFO -Message "[4/7] Ottimizzazione prestazioni..." -LogPath $LogPath
    $highPerfGuid = "8c5e7fda-e8bf-4a96-9a8f-a307e2250669"
    try {
        powercfg /setactive $highPerfGuid
        Write-Log -Level SUCCESS -Message "   - Schema energetico impostato su 'Prestazioni elevate'." -LogPath $LogPath
    } catch {
        Write-Log -Level WARN -Message "   - Impossibile impostare lo schema 'Prestazioni elevate'." -LogPath $LogPath
    }
    foreach ($serviceName in $config.ServicesToManage) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Stop-Service -Name $serviceName -Force
            Write-Log -Level SUCCESS -Message "   - Servizio interrotto: $serviceName" -LogPath $LogPath
        } else {
            Write-Log -Level VERBOSE -Message "Servizio '$serviceName' non in esecuzione o non trovato, ignorato." -LogPath $LogPath
        }
    }

    # 5. Pulizia File Temporanei
    Write-Log -Level INFO -Message "[5/7] Pulizia file temporanei..." -LogPath $LogPath
    $tempPaths = @("$env:TEMP", "$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Remove-Item -Path (Join-Path $path "*") -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level SUCCESS -Message "     - Pulita: $path" -LogPath $LogPath
        }
    }

    # 6. Ambiente Senza Distrazioni
    Write-Log -Level INFO -Message "[6/7] Creazione ambiente senza distrazioni..." -LogPath $LogPath
    try {
        if (Test-And-Create-RegistryPath -Path $quietHoursKey) {
            Write-Log -Level VERBOSE -Message "Creato percorso registro per QuietHours." -LogPath $LogPath
        }
        Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value 2 -Force
        Write-Log -Level SUCCESS -Message "   - Notifiche disattivate (Solo Sveglie)." -LogPath $LogPath

        if (Test-And-Create-RegistryPath -Path $gameBarAllowKey) {
            Write-Log -Level VERBOSE -Message "Creato percorso registro per GameBar (utente)." -LogPath $LogPath
        }
        Set-ItemProperty -Path $gameBarAllowKey -Name "AllowGameBar" -Value 0 -Type DWord -Force

        if (Test-And-Create-RegistryPath -Path $gameBarPolicyKey) {
            Write-Log -Level VERBOSE -Message "Creato percorso registro per GameBar (policy)." -LogPath $LogPath
        }
        Set-ItemProperty -Path $gameBarPolicyKey -Name "AllowGameDVR" -Value 0 -Type DWord -Force
        Write-Log -Level SUCCESS -Message "   - Xbox Game Bar disabilitata." -LogPath $LogPath
    } catch {
        Write-Log -Level ERROR -Message "Errore durante la configurazione dell'ambiente. Dettagli: $($_.Exception.Message)" -LogPath $LogPath
    }

    # 7. Pulizia Cestino (Opzionale)
    if ($config.EmptyRecycleBin) {
        Write-Log -Level INFO -Message "[7/7] Pulizia del Cestino in corso..." -LogPath $LogPath
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(10)
            if ($recycleBin.Items().Count -gt 0) {
                $recycleBin.Items() | ForEach-Object { $_.InvokeVerb("delete") }
                 Write-Log -Level SUCCESS -Message "   - Cestino svuotato." -LogPath $LogPath
            } else {
                 Write-Log -Level VERBOSE -Message "Cestino già vuoto." -LogPath $LogPath
            }
        } catch {
            Write-Log -Level WARN -Message "   - Impossibile svuotare il cestino. Errore: $($_.Exception.Message)" -LogPath $LogPath
        }
    }

    Write-Log -Level TITLE -Message "--- PREPARAZIONE COMPLETATA. In bocca al lupo! ---" -LogPath $LogPath
}


function Start-ExamRestore {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$LogPath
    )

    Write-Log -Level TITLE -Message "--- MODALITÀ RIPRISTINO POST-ESAME ATTIVATA ---" -LogPath $LogPath
    $backupFile = Join-Path $env:TEMP "ExamPrepBackup.json"

    if (-not (Test-Path $backupFile)) {
        Write-Log -Level ERROR -Message "File di backup non trovato. Impossibile ripristinare." -LogPath $LogPath
        return
    }

    $backupData = Get-Content -Path $backupFile | ConvertFrom-Json

    if (-not $PSCmdlet.ShouldProcess("il sistema allo stato pre-esame", "Sei sicuro di voler procedere con il ripristino?", "Conferma")) {
        Write-Log -Level WARN -Message "Operazione di ripristino annullata dall'utente." -LogPath $LogPath
        return
    }

    # 1. Ripristino Impostazioni
    Write-Log -Level INFO -Message "[1/3] Ripristino delle impostazioni di sistema..." -LogPath $LogPath
    try {
        if ($backupData.PowerScheme) {
            powercfg /setactive $backupData.PowerScheme
            Write-Log -Level SUCCESS -Message "   - Schema energetico ripristinato." -LogPath $LogPath
        } else {
            powercfg /setactive "381b4222-f694-41f0-9685-ff5bb260df2e" # Fallback a Bilanciato
            Write-Log -Level WARN -Message "   - Schema energetico impostato su 'Bilanciato' (predefinito)." -LogPath $LogPath
        }

        $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"
        $originalProfile = if ($null -ne $backupData.FocusAssistProfile) { $backupData.FocusAssistProfile } else { 0 }
        if (Test-And-Create-RegistryPath -Path $quietHoursKey) {
            Write-Log -Level VERBOSE -Message "Creato percorso registro per QuietHours." -LogPath $LogPath
        }
        Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value $originalProfile -Force
        Write-Log -Level SUCCESS -Message "   - Assistente notifiche ripristinato." -LogPath $LogPath

        $gameBarAllowKey = "HKCU:\Software\Microsoft\GameBar"
        $gameBarPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        $originalAllowValue = if ($null -ne $backupData.GameBarAllowed) { $backupData.GameBarAllowed } else { 1 }
        $originalPolicyValue = if ($null -ne $backupData.GameBarPolicy) { $backupData.GameBarPolicy } else { 1 }
        if(Test-And-Create-RegistryPath -Path $gameBarAllowKey) {
             Write-Log -Level VERBOSE -Message "Creato percorso registro per GameBar (utente)." -LogPath $LogPath
        }
        Set-ItemProperty -Path $gameBarAllowKey -Name "AllowGameBar" -Value $originalAllowValue -Type DWord -Force
        if(Test-And-Create-RegistryPath -Path $gameBarPolicyKey) {
            Write-Log -Level VERBOSE -Message "Creato percorso registro per GameBar (policy)." -LogPath $LogPath
        }
        Set-ItemProperty -Path $gameBarPolicyKey -Name "AllowGameDVR" -Value $originalPolicyValue -Type DWord -Force
        Write-Log -Level SUCCESS -Message "   - Xbox Game Bar riabilitata." -LogPath $LogPath

    } catch {
        Write-Log -Level ERROR -Message "Errore durante il ripristino. Dettagli: $($_.Exception.Message)" -LogPath $LogPath
    }

    # 2. Riattivazione Servizi
    Write-Log -Level INFO -Message "[2/3] Riavvio dei servizi..." -LogPath $LogPath
    foreach ($serviceEntry in $backupData.Services.PSObject.Properties) {
        $serviceName = $serviceEntry.Name
        $originalStatus = $serviceEntry.Value

        if ($originalStatus -eq 'Running') {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -ne 'Running') {
                Start-Service -Name $serviceName
                Write-Log -Level SUCCESS -Message "   - Servizio riavviato: $serviceName" -LogPath $LogPath
            }
        } else {
             Write-Log -Level VERBOSE -Message "Servizio '$serviceName' non era in esecuzione, non verrà riavviato." -LogPath $LogPath
        }
    }

    # 3. Pulizia
    Write-Log -Level INFO -Message "[3/3] Pulizia e completamento..." -LogPath $LogPath
    Remove-Item -Path $backupFile -Force
    Write-Log -Level INFO -Message "   - File di backup rimosso." -LogPath $LogPath

    Write-Log -Level TITLE -Message "--- RIPRISTINO COMPLETATO. Ben fatto! ---" -LogPath $LogPath
}

# Esporta le funzioni pubbliche per renderle disponibili all'utente del modulo.
Export-ModuleMember -Function Start-ExamPreparation, Start-ExamRestore

# --- FINE MODULO POWERSHELL ExamPrep ---