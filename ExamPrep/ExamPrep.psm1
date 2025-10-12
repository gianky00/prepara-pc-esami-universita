# --- INIZIO MODULO POWERSHELL ExamPrep ---
# Versione 11.0.0: Backup persistente per un ripristino a prova di proiettile.

#region Variabili Script-Scoped
$Script:GlobalLogPath = $null
$Script:GlobalConfig = $null
#endregion

#region Funzioni Private (Interne al Modulo)

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS","TITLE","VERBOSE")][string]$Level="INFO"
    )
    if ($Script:GlobalLogPath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] - $Message"
        try { Add-Content -Path $Script:GlobalLogPath -Value $logEntry -ErrorAction Stop } catch { Write-Warning "Impossibile scrivere nel log: $($_.Exception.Message)" }
    }
    if ($Level -eq "VERBOSE") { Write-Verbose $Message; return }
    $color = switch ($Level) { "WARN"{"Yellow"};"ERROR"{"Red"};"SUCCESS"{"Green"};"TITLE"{"Cyan"};default{"White"} }
    $consoleMessage = if ($Level -in "INFO","WARN","ERROR","SUCCESS") { "[$($Level.PadRight(7))] $Message" } else { $Message }
    Write-Host $consoleMessage -ForegroundColor $color
}

function Get-ExamPrepConfig {
    param([string]$ConfigPath)
    try {
        if (-not (Test-Path $ConfigPath)) { throw "File di configurazione non trovato: $ConfigPath" }
        return Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    }
    catch { throw "Errore lettura config: $($_.Exception.Message)" }
}

function Test-And-Create-RegistryPath {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null; return $true }
        catch { throw "Impossibile creare percorso registro: $($_.Exception.Message)" }
    }
    return $false
}

function Get-DiscoverableProcesses {
    param([string[]]$KnownProcesses)
    $windowsPath = $env:SystemRoot
    Write-Log -Level VERBOSE -Message "Avvio scansione processi utente..."
    try {
        # Aggiunge i nomi dei file degli eseguibili dei proctor alla lista dei processi conosciuti
        $proctorExecutables = $Script:GlobalConfig.ProctoringAppPaths | ForEach-Object { [System.IO.Path]::GetFileName($_) }
        $allKnown = $KnownProcesses + $proctorExecutables

        $processes = Get-Process | Where-Object { $_.MainWindowTitle -and $_.Path -and -not $_.Path.StartsWith($windowsPath) } | Select-Object -ExpandProperty ProcessName -Unique
        $knownProcessesLower = $allKnown | ForEach-Object { $_.ToLower() }
        $discovered = $processes | Where-Object { ($_.ToLower() + ".exe") -notin $knownProcessesLower }
        return $discovered
    } catch { Write-Log -Level WARN -Message "Impossibile scansionare i processi. Errore: $($_.Exception.Message)"; return @() }
}

function Update-ExamPrepConfig {
    param([string]$ConfigPath, [string]$Key, [string]$Value)
    try {
        $configObject = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        if ($configObject.PSObject.Properties[$Key]) {
            $list = $configObject.PSObject.Properties[$Key].Value
            if ($Value -notin $list) {
                $list.Add($Value)
                $configObject | ConvertTo-Json -Depth 5 | Out-File -FilePath $ConfigPath -Encoding UTF8
                Write-Log -Level VERBOSE -Message "Aggiunto '$Value' a '$Key' nel file di configurazione."
            }
        }
    } catch { Write-Log -Level WARN -Message "Impossibile aggiornare il file di configurazione. Errore: $($_.Exception.Message)" }
}

function Find-ExecutablePath {
    param([string]$ExecutableName)

    # CORREZIONE: Filtra i percorsi di base per escludere quelli nulli o non esistenti
    # prima di tentare di cercare file al loro interno.
    $basePaths = @(
        $env:ProgramFiles,
        $env:ProgramFilesX86,
        $env:LOCALAPPDATA,
        $env:APPDATA
    ) | Where-Object { -not [string]::IsNullOrEmpty($_) -and (Test-Path $_) }

    Write-Log -Level VERBOSE -Message "Ricerca di '$ExecutableName' nelle seguenti directory di base: $($basePaths -join ', ')"

    foreach ($basePath in $basePaths) {
        $searchPath = Join-Path $basePath "*"
        try {
            $found = Get-ChildItem -Path $searchPath -Recurse -Filter $ExecutableName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                Write-Log -Level VERBOSE -Message "Trovato '$ExecutableName' in: $($found.FullName)"
                return $found.FullName
            }
        } catch {
            # Ignora errori di accesso negato e continua la ricerca
        }
    }

    Write-Log -Level VERBOSE -Message "'$ExecutableName' non trovato nei percorsi di installazione comuni."
    return $null
}

function Invoke-ProcessClassifier {
    param($DiscoveredProcesses, $ConfigPath)
    $sessionKillList = [System.Collections.Generic.List[string]]@()
    $sessionAllowList = [System.Collections.Generic.List[string]]@()
    Write-Log -Level INFO -Message "Trovati $($DiscoveredProcesses.Count) processi non configurati. Inizio classificazione:"
    foreach ($processName in $DiscoveredProcesses) {
        $title = "Processo non configurato: '$($processName.ToUpper())'"
        $message = "Cosa vuoi fare con questo processo?"
        $choices = @(
            New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Chiudi (solo per questa sessione)', 'Termina questo processo adesso.'
            New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Ignora (solo per questa sessione)', 'Lascia questo processo in esecuzione.'
            New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList 'Chiudi [S]empre', "Aggiungi alla lista 'ProcessesToKill' per il futuro."
            New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList 'Ignora se[m]pre', "Aggiungi alla lista 'AllowedApplications' per il futuro."
            New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList 'Ignora [t]utti i rimanenti', 'Salta la classificazione per gli altri processi.'
        )
        $decision = $Host.UI.PromptForChoice($title, $message, $choices, 0)
        $processExe = "$processName.exe"
        switch ($decision) {
            0 { $sessionKillList.Add($processExe); Write-Log -Level INFO "Decisione temporanea: Chiudi '$processExe'" }
            1 { $sessionAllowList.Add($processExe); Write-Log -Level INFO "Decisione temporanea: Ignora '$processExe'" }
            2 { Update-ExamPrepConfig -ConfigPath $ConfigPath -Key 'ProcessesToKill' -Value $processExe; $sessionKillList.Add($processExe); Write-Log -Level SUCCESS "Configurazione aggiornata: '$processExe' verrà sempre chiuso." }
            3 { Update-ExamPrepConfig -ConfigPath $ConfigPath -Key 'AllowedApplications' -Value $processExe; $sessionAllowList.Add($processExe); Write-Log -Level SUCCESS "Configurazione aggiornata: '$processExe' verrà sempre ignorato." }
            4 { Write-Log -Level WARN "Tutti i restanti processi non configurati verranno ignorati per questa sessione."; return @{ Kill = $sessionKillList; Allow = $sessionAllowList } }
        }
    }
    return @{ Kill = $sessionKillList; Allow = $sessionAllowList }
}
#endregion

#region Funzioni Pubbliche (Esportate dal Modulo)

function Start-ExamPreparation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    $Script:GlobalLogPath = $LogPath
    Write-Log -Level TITLE -Message "--- MODALITÀ PREPARAZIONE ESAME v11.0 (Élite Stabile) ---"
    try { $Script:GlobalConfig = Get-ExamPrepConfig -ConfigPath $ConfigPath }
    catch { Write-Log -Level ERROR -Message $_.Exception.Message; return }

    # 1. Backup
    $backupDir = Join-Path $env:LOCALAPPDATA "ExamPrep"
    $backupFile = Join-Path $backupDir "ExamPrepAdvancedBackup.json"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

    $backupData = @{ Services = @(); VisualEffects = @{}; Network = @{}; ProctorProcess = @{}; QuietHours = $null; GameBar = @{}; NetworkAdapters = @() }
    Write-Log -Level INFO -Message "[1/10] Esecuzione backup in posizione sicura..."
    try {
        $activeSchemeOutput = powercfg /getactivescheme
        $guidMatch = $activeSchemeOutput | Select-String -Pattern '[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}'
        if ($guidMatch) { $backupData.PowerScheme = $guidMatch.Matches[0].Value } else { throw "Impossibile trovare GUID schema energetico." }

        # Backup dello stato dei servizi (Base e Avanzato)
        $servicesToBackup = [System.Collections.Generic.List[string]]@($Script:GlobalConfig.ServicesToManage)
        if ($Script:GlobalConfig.AdvancedServiceManagement.Enabled) {
        # In modalità avanzata, scopri tutti i servizi non-Microsoft, escludendo quelli da ignorare
        $servicesToIgnore = $Script:GlobalConfig.ServicesToIgnore
        $nonMicrosoftServices = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.PathName -and -not $_.PathName.StartsWith($env:SystemRoot) -and $_.Name -notin $servicesToIgnore }
            foreach($s in $nonMicrosoftServices) { $servicesToBackup.Add($s.Name) }
        }

        foreach ($serviceName in ($servicesToBackup | Select-Object -Unique)) {
            $service = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'"
            if ($service) {
                $backupData.Services += @{
                    Name      = $service.Name
                    State     = $service.State
                    StartMode = $service.StartMode
                }
            }
        }

        $backupData.VisualEffects.UserPreferencesMask = Get-ItemPropertyValue -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -ErrorAction SilentlyContinue

    # Trova il percorso dell'eseguibile del proctor, iterando sui percorsi specificati
        $proctorExePath = $null
    $proctorAppName = $null
    foreach ($path in $Script:GlobalConfig.ProctoringAppPaths) {
        if (Test-Path $path) {
            $proctorExePath = $path
            $proctorAppName = [System.IO.Path]::GetFileName($path)
            Write-Log -Level VERBOSE "Trovato eseguibile proctor valido: $proctorExePath"
            break
        }
    }

    $proctorProc = if ($proctorAppName) { Get-Process -Name $proctorAppName.Replace(".exe", "") -ErrorAction SilentlyContinue } else { $null }
        if ($proctorProc) {
            $backupData.ProctorProcess.Priority = $proctorProc.PriorityClass
        Write-Log -Level VERBOSE "Applicazione proctor '$proctorAppName' trovata in esecuzione."
        }

        # Se abbiamo trovato il percorso, salvalo ed esegui il backup delle impostazioni associate
        if ($proctorExePath) {
            $backupData.ProctorProcess.Path = $proctorExePath
            $backupData.ProctorProcess.AppName = $proctorAppName
            $gpuPrefKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
            $backupData.ProctorProcess.GpuPreference = Get-ItemPropertyValue -Path $gpuPrefKey -Name $proctorExePath -ErrorAction SilentlyContinue
            Write-Log -Level VERBOSE "Percorso eseguibile del proctor ('$proctorExePath') salvato per le ottimizzazioni."
        } else {
            Write-Log -Level WARN "Impossibile trovare l'eseguibile di alcuna applicazione proctor. Le ottimizzazioni specifiche (GPU, QoS) non verranno applicate."
        }

        # CORREZIONE: Seleziona solo la prima configurazione di rete attiva per evitare errori
        # in sistemi con più adattatori di rete (es. VPN, VirtualBox).
        $ipconfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up'} | Select-Object -First 1
        if ($ipconfig) {
            $interfaceGuid = $ipconfig.NetAdapter.InterfaceGuid; $backupData.Network.InterfaceGuid = $interfaceGuid
            $nagleKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$interfaceGuid"
            if (Test-Path $nagleKeyPath) {
                $regKey = Get-Item -Path $nagleKeyPath
                if ($null -ne $regKey.GetValue("TcpAckFrequency", $null)) { $backupData.Network.TcpAckFrequency = $regKey.GetValue("TcpAckFrequency") }
                if ($null -ne $regKey.GetValue("TCPNoDelay", $null)) { $backupData.Network.TCPNoDelay = $regKey.GetValue("TCPNoDelay") }
            }
        }

        $backupData.QuietHours = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" -Name "QuietHoursProfile" -ErrorAction SilentlyContinue
        $backupData.GameBar.AllowGameBar = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowGameBar" -ErrorAction SilentlyContinue

        # Backup dello stato degli adattatori di rete
        $backupData.NetworkAdapters = Get-NetAdapter -IncludeHidden | ForEach-Object {
            @{
                InterfaceDescription = $_.InterfaceDescription
                Status = $_.Status
            }
        }

        $backupData | ConvertTo-Json -Depth 5 | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Log -Level SUCCESS -Message "   - Backup completato in '$backupFile'."
    } catch { Write-Log -Level ERROR -Message "Errore durante il backup: $($_.Exception.Message)"; return }

    # 2. Scoperta e Classificazione Processi
    Write-Log -Level INFO -Message "[2/10] Scansione per processi non configurati..."
    $knownProcesses = $Script:GlobalConfig.ProcessesToKill + $Script:GlobalConfig.AllowedApplications
    $discovered = Get-DiscoverableProcesses -KnownProcesses $knownProcesses
    $sessionDecisions = if ($discovered.Count -gt 0) { Invoke-ProcessClassifier -DiscoveredProcesses $discovered -ConfigPath $ConfigPath }
    else { Write-Log -Level VERBOSE -Message "Nessun nuovo processo da classificare."; @{ Kill = @(); Allow = @() } }

    # 3. Conferma Utente Finale
    if (-not $PSCmdlet.ShouldProcess("il sistema per la preparazione all'esame", "Sei sicuro di voler procedere?", "Conferma")) {
        Write-Log -Level WARN -Message "Operazione annullata dall'utente."; Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue; return
    }

    # 4. Terminazione Processi
    Write-Log -Level INFO -Message "[4/10] Terminazione processi..."
    $Script:GlobalConfig = Get-ExamPrepConfig -ConfigPath $ConfigPath
    $killList = ($Script:GlobalConfig.ProcessesToKill + $sessionDecisions.Kill) | Where-Object { $_ -notin ($Script:GlobalConfig.AllowedApplications + $sessionDecisions.Allow) } | Select-Object -Unique
    foreach ($process in $killList) {
        $procName = $process.Replace(".exe", ""); if (Get-Process -Name $procName -ErrorAction SilentlyContinue) { Stop-Process -Name $procName -Force; Write-Log -Level SUCCESS "   - Terminato: $process" }
    }

    # 5. Gestione Adattatori di Rete
    if ($Script:GlobalConfig.NetworkAdapterManagement.Enabled) {
        Write-Log -Level INFO -Message "[5/10] Gestione degli adattatori di rete..."
        $primaryAdapter = $Script:GlobalConfig.NetworkAdapterManagement.PrimaryInterfaceDescription
        $adaptersToDisable = $backupData.NetworkAdapters | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -ne $primaryAdapter -and $_.InterfaceDescription -notlike "WAN Miniport*" }
        if ($adaptersToDisable) {
            foreach ($adapterInfo in $adaptersToDisable) {
                try {
                    Disable-NetAdapter -InterfaceDescription $adapterInfo.InterfaceDescription -Confirm:$false -ErrorAction Stop
                    Write-Log -Level SUCCESS "   - Adattatore di rete disabilitato: $($adapterInfo.InterfaceDescription)"
                } catch {
                    Write-Log -Level WARN "   - Impossibile disabilitare l'adattatore '$($adapterInfo.InterfaceDescription)'. Errore: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Log -Level VERBOSE -Message "Nessun adattatore di rete non primario da disabilitare."
        }
    }

    # 6. Gestione Servizi di Background
    Write-Log -Level INFO -Message "[6/10] Gestione dei servizi di background..."
    $servicesToStop = $backupData.Services | Where-Object { $_.Name -in $Script:GlobalConfig.ServicesToManage -and $_.State -eq 'Running' }
    foreach ($service in $servicesToStop) {
        try {
            Stop-Service -Name $service.Name -Force -ErrorAction Stop
            Write-Log -Level SUCCESS "   - Servizio base interrotto: $($service.Name)"
        } catch { Write-Log -Level WARN "   - Impossibile interrompere il servizio '$($service.Name)'." }
    }
    if ($Script:GlobalConfig.AdvancedServiceManagement.Enabled) {
        $servicesToDisable = $backupData.Services | Where-Object { ($_.Name -notin $Script:GlobalConfig.ServicesToManage) -and ($_.StartMode -ne 'Disabled') }
        if ($servicesToDisable) {
            Write-Log -Level INFO "   - Modalità avanzata: disabilitazione di $($servicesToDisable.Count) servizi di terze parti."
            foreach ($service in $servicesToDisable) {
                try {
                    Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop
                    Write-Log -Level SUCCESS "     - Servizio disabilitato (avvio impedito): $($service.Name)"
                } catch { Write-Log -Level WARN "     - Impossibile disabilitare il servizio '$($service.Name)'. Errore: $($_.Exception.Message)" }
            }
        }
    }

    # 7. Ottimizzazioni Avanzate PC
    if ($Script:GlobalConfig.AdvancedOptimizations.EnablePCPerformance) {
        Write-Log -Level INFO -Message "[7/10] Applicazione ottimizzazioni PC avanzate..."
        if ($proctorProc) {
            # Il processo è in esecuzione, quindi è possibile impostare la priorità della CPU.
            $proctorProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
            Write-Log -Level SUCCESS "   - Priorità CPU di '$($backupData.ProctorProcess.AppName)' impostata su 'Alta'."
        }
        else {
            # Il processo non è in esecuzione, logga un avviso informativo.
            Write-Log -Level WARN "   - Applicazione proctor non in esecuzione, l'ottimizzazione della priorità CPU è stata saltata."
            Write-Log -Level INFO "   - Le altre ottimizzazioni persistenti (GPU, Rete) verranno applicate all'avvio dell'app."
        }

        # Applica ottimizzazione GPU persistente usando il path dell'eseguibile trovato
        if ($backupData.ProctorProcess.Path) {
            $gpuPrefKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"; Test-And-Create-RegistryPath -Path $gpuPrefKey | Out-Null
            Set-ItemProperty -Path $gpuPrefKey -Name $backupData.ProctorProcess.Path -Value "GpuPreference=2;"; Write-Log -Level SUCCESS "   - Prestazioni GPU per '$($backupData.ProctorProcess.AppName)' impostate su 'Elevate' (persistente)."
        }

        $perfMask = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00); Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $perfMask -Type Binary
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFX" -Value 2; Write-Log -Level SUCCESS "   - Effetti visivi di Windows impostati per massime prestazioni."
    }

    # 8. Ottimizzazioni Avanzate Rete
    if ($Script:GlobalConfig.AdvancedOptimizations.EnableNetworkPerformance) {
        Write-Log -Level INFO -Message "[8/10] Applicazione ottimizzazioni Rete avanzate..."
        # Applica policy QoS persistente usando il path dell'eseguibile trovato
        if ($backupData.ProctorProcess.Path) {
            try { New-NetQosPolicy -Name "ExamPrepProctoring" -AppPathNameMatchCondition $backupData.ProctorProcess.Path -PriorityValue8021Action 7 -ErrorAction Stop; Write-Log -Level SUCCESS "   - Policy QoS creata per '$($backupData.ProctorProcess.AppName)' (persistente)." }
            catch { Write-Log -Level WARN "   - Impossibile creare policy QoS." }
        }
        if ($backupData.Network.InterfaceGuid -and $Script:GlobalConfig.AdvancedOptimizations.DisableNagleAlgorithm) {
            $nagleKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($backupData.Network.InterfaceGuid)"
            Test-And-Create-RegistryPath -Path $nagleKeyPath | Out-Null; Set-ItemProperty -Path $nagleKeyPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force; Set-ItemProperty -Path $nagleKeyPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
            Write-Log -Level SUCCESS "   - Algoritmo di Nagle disabilitato."
        }
    }

    # 9. Ottimizzazioni Base
    Write-Log -Level INFO -Message "[9/10] Applicazione ottimizzazioni di base..."
    $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"; Test-And-Create-RegistryPath -Path $quietHoursKey | Out-Null; Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value 2 -Force; Write-Log -Level SUCCESS "   - Notifiche disattivate (Solo Sveglie)."
    $gameBarKey = "HKCU:\Software\Microsoft\GameBar"; Test-And-Create-RegistryPath -Path $gameBarKey | Out-Null; Set-ItemProperty -Path $gameBarKey -Name "AllowGameBar" -Value 0 -Type DWord -Force; Write-Log -Level SUCCESS "   - Xbox Game Bar disabilitata."

    $ultimateGuid = $Script:GlobalConfig.PowerPlanOptimizations.UltimatePerformanceGuid
    $highPerfGuid = $Script:GlobalConfig.PowerPlanOptimizations.HighPerformanceGuid
    $powerPlans = powercfg /list
    if ($powerPlans -match $ultimateGuid) {
        powercfg /setactive $ultimateGuid
        Write-Log -Level SUCCESS "   - Schema energetico impostato su 'Prestazioni Eccellenti'."
    }
    elseif ($powerPlans -match $highPerfGuid) {
        powercfg /setactive $highPerfGuid
        Write-Log -Level SUCCESS "   - Schema energetico impostato su 'Prestazioni Elevate'."
    }
    else {
        Write-Log -Level WARN "   - Schemi energetici ottimali non trovati. Le prestazioni potrebbero non essere massime."
    }

    Get-Item -Path "$env:TEMP\*", "$env:SystemRoot\Temp\*", "$env:SystemRoot\Prefetch\*" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Log -Level SUCCESS "   - File temporanei puliti."

    # 10. Pulizia Cestino
    if ($Script:GlobalConfig.EmptyRecycleBin) { Write-Log -Level INFO -Message "[10/10] Pulizia del Cestino..."; try { (New-Object -ComObject Shell.Application).Namespace(10).Items() | ForEach-Object { $_.InvokeVerb("delete") }; Write-Log -Level SUCCESS "   - Cestino svuotato." } catch { Write-Log -Level WARN "   - Impossibile svuotare il Cestino." } }

    Write-Log -Level TITLE -Message "--- PREPARAZIONE COMPLETATA. In bocca al lupo! ---"
}

function Start-ExamRestore {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    $Script:GlobalLogPath = $LogPath
    Write-Log -Level TITLE -Message "--- MODALITÀ RIPRISTINO POST-ESAME v11.0 ---"
    $backupFile = Join-Path $env:LOCALAPPDATA "ExamPrep\ExamPrepAdvancedBackup.json"
    if (-not (Test-Path $backupFile)) { Write-Log -Level ERROR "File di backup non trovato in '$backupFile'. Impossibile ripristinare."; return }
    $backupData = Get-Content -Path $backupFile | ConvertFrom-Json
    if (-not $PSCmdlet.ShouldProcess("il sistema allo stato pre-esame", "Conferma ripristino", "Conferma")) { Write-Log -Level WARN "Ripristino annullato."; return }

    # 1. Ripristino Ottimizzazioni Avanzate
    Write-Log -Level INFO -Message "[1/3] Ripristino ottimizzazioni avanzate..."
    try {
        $Script:GlobalConfig = Get-ExamPrepConfig -ConfigPath $ConfigPath
        if ($backupData.ProctorProcess.AppName) {
            $proctorProc = Get-Process -Name $backupData.ProctorProcess.AppName.Replace(".exe", "") -ErrorAction SilentlyContinue
            if ($proctorProc -and $backupData.ProctorProcess.Priority) {
                $proctorProc.PriorityClass = $backupData.ProctorProcess.Priority
                Write-Log -Level SUCCESS "   - Priorità CPU di '$($backupData.ProctorProcess.AppName)' ripristinata."
            }
        }
        if ($backupData.ProctorProcess.Path) {
            $gpuPrefKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
            if ($null -eq $backupData.ProctorProcess.GpuPreference) { Remove-ItemProperty -Path $gpuPrefKey -Name $backupData.ProctorProcess.Path -EA SilentlyContinue }
            else { Set-ItemProperty -Path $gpuPrefKey -Name $backupData.ProctorProcess.Path -Value $backupData.ProctorProcess.GpuPreference }
            Write-Log -Level SUCCESS "   - Impostazione persistente delle prestazioni GPU ripristinata."
        }
        if ($null -ne $backupData.VisualEffects.UserPreferencesMask) {
            # CORREZIONE BUG: Il valore deserializzato da JSON è un PSCustomObject.
            # È necessario estrarre l'array di byte dalla proprietà 'value' e fare il cast a [byte[]].
            $restoredMaskBytes = [byte[]]$backupData.VisualEffects.UserPreferencesMask.value
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $restoredMaskBytes -Type Binary -Force

            # Forza un aggiornamento dell'interfaccia utente per applicare immediatamente le modifiche visive
            try {
                $user32 = Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);' -Name "User32" -Namespace "Win32" -PassThru
                $user32::SystemParametersInfo(0x0057, 0, $null, 3) # SPI_SETDESKWALLPAPER with SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
                Write-Log -Level SUCCESS "   - Effetti visivi di Windows ripristinati e applicati."
            } catch {
                Write-Log -Level WARN "   - Non è stato possibile forzare l'aggiornamento degli effetti visivi. Potrebbe essere necessario un riavvio."
            }
        }
        Remove-NetQosPolicy -Name "ExamPrepProctoring" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-Log -Level SUCCESS "   - Policy QoS persistente rimossa."
        if ($backupData.Network.InterfaceGuid) {
            $nagleKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($backupData.Network.InterfaceGuid)"
            if (Test-Path $nagleKeyPath) {
                if ($null -eq $backupData.Network.TcpAckFrequency) { Remove-ItemProperty -Path $nagleKeyPath -Name "TcpAckFrequency" -EA SilentlyContinue } else { Set-ItemProperty -Path $nagleKeyPath -Name "TcpAckFrequency" -Value $backupData.Network.TcpAckFrequency -Type DWord -Force }
                if ($null -eq $backupData.Network.TCPNoDelay) { Remove-ItemProperty -Path $nagleKeyPath -Name "TCPNoDelay" -EA SilentlyContinue } else { Set-ItemProperty -Path $nagleKeyPath -Name "TCPNoDelay" -Value $backupData.Network.TCPNoDelay -Type DWord -Force }
                Write-Log -Level SUCCESS "   - Algoritmo di Nagle ripristinato."
            }
        }
    } catch { Write-Log -Level WARN "Errore non critico durante ripristino avanzato: $($_.Exception.Message)" }

    # 2. Ripristino Ottimizzazioni Base
    Write-Log -Level INFO -Message "[2/5] Ripristino ottimizzazioni di base..."
    $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"; Test-And-Create-RegistryPath -Path $quietHoursKey | Out-Null; $originalProfile = if($null -ne $backupData.QuietHours){$backupData.QuietHours}else{0}; Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value $originalProfile -Force; Write-Log -Level SUCCESS "   - Assistente notifiche ripristinato."
    $gameBarKey = "HKCU:\Software\Microsoft\GameBar"; Test-And-Create-RegistryPath -Path $gameBarKey | Out-Null; $originalGameBar = if($null -ne $backupData.GameBar.AllowGameBar){$backupData.GameBar.AllowGameBar}else{1}; Set-ItemProperty -Path $gameBarKey -Name "AllowGameBar" -Value $originalGameBar -Type DWord -Force; Write-Log -Level SUCCESS "   - Xbox Game Bar ripristinata."
    powercfg /setactive $backupData.PowerScheme; Write-Log -Level SUCCESS "   - Schema energetico ripristinato."

    # 3. Ripristino Servizi di Background
    Write-Log -Level INFO -Message "[3/5] Ripristino dei servizi di background..."
    if ($backupData.Services) {
        foreach ($serviceInfo in $backupData.Services) {
            try {
                # CORREZIONE: Traduce il valore 'Auto' restituito da WMI nel valore 'Automatic'
                # richiesto dal cmdlet Set-Service per garantire la compatibilità.
                $startupType = $serviceInfo.StartMode
                if ($startupType -eq 'Auto') { $startupType = 'Automatic' }

                # Ripristina prima la modalità di avvio
                Set-Service -Name $serviceInfo.Name -StartupType $startupType -ErrorAction Stop
                Write-Log -Level SUCCESS "   - Modalità di avvio per '$($serviceInfo.Name)' ripristinata a '$($startupType)'."

                # Se il servizio era in esecuzione, prova a riavviarlo
                if ($serviceInfo.State -eq 'Running') {
                    Start-Service -Name $serviceInfo.Name -ErrorAction SilentlyContinue # SilentlyContinue qui è accettabile
                    Write-Log -Level SUCCESS "   - Servizio '$($serviceInfo.Name)' riavviato."
                }
            } catch {
                Write-Log -Level WARN "   - Impossibile ripristinare completamente il servizio '$($serviceInfo.Name)'. Errore: $($_.Exception.Message)"
            }
        }
    }

    # 4. Ripristino Adattatori di Rete
    if ($Script:GlobalConfig.NetworkAdapterManagement.Enabled -and $backupData.NetworkAdapters) {
        Write-Log -Level INFO -Message "[4/5] Ripristino adattatori di rete..."
        foreach ($adapterInfo in $backupData.NetworkAdapters) {
            if ($adapterInfo.Status -eq 'Up') {
                try {
                    Enable-NetAdapter -InterfaceDescription $adapterInfo.InterfaceDescription -Confirm:$false -ErrorAction Stop
                    Write-Log -Level SUCCESS "   - Adattatore di rete ri-abilitato: $($adapterInfo.InterfaceDescription)"
                } catch {
                    Write-Log -Level WARN "   - Impossibile ri-abilitare l'adattatore '$($adapterInfo.InterfaceDescription)'. Potrebbe essere necessario farlo manualmente. Errore: $($_.Exception.Message)"
                }
            }
        }
    }

    # 5. Pulizia
    Write-Log -Level INFO -Message "[5/5] Pulizia file di backup..."
    Remove-Item -Path $backupFile -Force; Write-Log -Level SUCCESS "   - File di backup rimosso."

    Write-Log -Level TITLE -Message "--- RIPRISTINO COMPLETATO. Ben fatto! ---"
}

function New-ExamPrepReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportPath
    )

    $ErrorActionPreference = "SilentlyContinue"
    Write-Log -Level TITLE -Message "--- GENERAZIONE REPORT DI SISTEMA v13.0 ---"

    # Funzione helper nidificata per mantenere pulito lo scope del modulo
    Function Run-And-Log-Report {
        param(
            [string]$Title,
            [scriptblock]$Command,
            [string]$FilePath
        )
        Add-Content -Path $FilePath -Value "`n`n--- $Title ---`n" -Encoding UTF8
        try {
            $output = & $Command 2>&1 | Out-String
            Add-Content -Path $FilePath -Value $output -Encoding UTF8
            Write-Log -Level SUCCESS "   - Report per '$Title' completato."
        } catch {
            $errorMessage = "ERRORE CRITICO DURANTE L'ESECUZIONE DI '$Title': $($_.Exception.Message)"
            Add-Content -Path $FilePath -Value $errorMessage -Encoding UTF8
            Write-Log -Level ERROR "   - Esecuzione di '$Title' fallita."
        }
    }

    $header = "=================================================================`n                REPORT DI SISTEMA - $(Get-Date)`n================================================================="
    # CORREZIONE: Usa l'encoding 'UTF8' standard, che in PowerShell moderno include il BOM,
    # garantendo la compatibilità senza causare errori.
    Set-Content -Path $ReportPath -Value $header -Encoding UTF8

    Run-And-Log-Report -Title "INFORMAZIONI DI SISTEMA (SYSTEMINFO)" -Command { systeminfo } -FilePath $ReportPath
    Run-And-Log-Report -Title "INFORMAZIONI PROCESSORE (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List } -FilePath $ReportPath
    Run-And-Log-Report -Title "INFORMAZIONI SCHEDA VIDEO (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_VideoController | Select-Object Name, DriverVersion, AdapterRAM | Format-List } -FilePath $ReportPath
    Run-And-Log-Report -Title "INFORMAZIONI MEMORIA RAM (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object BankLabel, @{n="Capacity(GB)";e={[math]::Round($_.Capacity / 1GB)}}, MemoryType, Speed | Format-Table } -FilePath $ReportPath
    Run-And-Log-Report -Title "INFORMAZIONI DISCHI FISICI (Get-CimInstance)" -Command { Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Model, @{n="Size(GB)";e={[math]::Round($_.Size / 1GB)}}, InterfaceType | Format-Table } -FilePath $ReportPath
    Run-And-Log-Report -Title "CONFIGURAZIONE DI RETE (IPCONFIG)" -Command { ipconfig /all } -FilePath $ReportPath
    Run-And-Log-Report -Title "PIANI DI RISPARMIO ENERGETICO (POWERCFG)" -Command { powercfg /list } -FilePath $ReportPath

    $footer = "`n`n=================================================================`n                     FINE DEL REPORT`n================================================================="
    Add-Content -Path $ReportPath -Value $footer -Encoding UTF8

    Write-Log -Level TITLE -Message "Report creato con successo in '$ReportPath'."
    try {
        Start-Process notepad $ReportPath
    } catch {
        Write-Log -Level WARN "Impossibile aprire il file di report automaticamente."
    }
}

Export-ModuleMember -Function Start-ExamPreparation, Start-ExamRestore, New-ExamPrepReport
# --- FINE MODULO POWERSHELL ExamPrep ---