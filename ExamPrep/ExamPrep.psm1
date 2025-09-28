# --- INIZIO MODULO POWERSHELL ExamPrep ---
# Versione 10.0.0: Versione Élite Definitiva, Stabile e Corretta.

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
        $processes = Get-Process | Where-Object { $_.MainWindowTitle -and $_.Path -and -not $_.Path.StartsWith($windowsPath) } | Select-Object -ExpandProperty ProcessName -Unique
        $knownProcessesLower = $KnownProcesses | ForEach-Object { $_.ToLower() }
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
    Write-Log -Level TITLE -Message "--- MODALITÀ PREPARAZIONE ESAME v10.0 (Élite Stabile) ---"
    try { $Script:GlobalConfig = Get-ExamPrepConfig -ConfigPath $ConfigPath }
    catch { Write-Log -Level ERROR -Message $_.Exception.Message; return }

    # 1. Backup
    $backupFile = Join-Path $env:TEMP "ExamPrepAdvancedBackup.json"
    $backupData = @{ Services = @{}; VisualEffects = @{}; Network = @{}; ProctorProcess = @{}; QuietHours = $null; GameBar = @{} }
    Write-Log -Level INFO -Message "[1/8] Esecuzione backup avanzato..."
    try {
        $activeSchemeOutput = powercfg /getactivescheme
        $guidMatch = $activeSchemeOutput | Select-String -Pattern '[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}'
        if ($guidMatch) { $backupData.PowerScheme = $guidMatch.Matches[0].Value } else { throw "Impossibile trovare GUID schema energetico." }

        foreach ($serviceName in $Script:GlobalConfig.ServicesToManage) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) { $backupData.Services[$serviceName] = $service.Status }
        }

        $backupData.VisualEffects.UserPreferencesMask = Get-ItemPropertyValue -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -ErrorAction SilentlyContinue

        $proctorProc = Get-Process -Name $Script:GlobalConfig.ProctoringAppName.Replace(".exe", "") -ErrorAction SilentlyContinue
        if ($proctorProc) {
            $backupData.ProctorProcess.Priority = $proctorProc.PriorityClass
            $backupData.ProctorProcess.Path = $proctorProc.Path
            $gpuPrefKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
            $backupData.ProctorProcess.GpuPreference = Get-ItemPropertyValue -Path $gpuPrefKey -Name $proctorProc.Path -ErrorAction SilentlyContinue
        }

        $ipconfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up'}
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

        $backupData | ConvertTo-Json -Depth 5 | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Log -Level SUCCESS -Message "   - Backup completato."
    } catch { Write-Log -Level ERROR -Message "Errore durante il backup: $($_.Exception.Message)"; return }

    # 2. Scoperta e Classificazione Processi
    Write-Log -Level INFO -Message "[2/8] Scansione per processi non configurati..."
    $knownProcesses = $Script:GlobalConfig.ProcessesToKill + $Script:GlobalConfig.AllowedApplications + @($Script:GlobalConfig.ProctoringAppName)
    $discovered = Get-DiscoverableProcesses -KnownProcesses $knownProcesses
    $sessionDecisions = if ($discovered.Count -gt 0) { Invoke-ProcessClassifier -DiscoveredProcesses $discovered -ConfigPath $ConfigPath }
    else { Write-Log -Level VERBOSE -Message "Nessun nuovo processo da classificare."; @{ Kill = @(); Allow = @() } }

    # 3. Conferma Utente Finale
    if (-not $PSCmdlet.ShouldProcess("il sistema per la preparazione all'esame", "Sei sicuro di voler procedere?", "Conferma")) {
        Write-Log -Level WARN -Message "Operazione annullata dall'utente."; Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue; return
    }

    # 4. Terminazione Processi
    Write-Log -Level INFO -Message "[4/8] Terminazione processi..."
    $Script:GlobalConfig = Get-ExamPrepConfig -ConfigPath $ConfigPath
    $killList = ($Script:GlobalConfig.ProcessesToKill + $sessionDecisions.Kill) | Where-Object { $_ -notin ($Script:GlobalConfig.AllowedApplications + $sessionDecisions.Allow) } | Select-Object -Unique
    foreach ($process in $killList) {
        $procName = $process.Replace(".exe", ""); if (Get-Process -Name $procName -ErrorAction SilentlyContinue) { Stop-Process -Name $procName -Force; Write-Log -Level SUCCESS "   - Terminato: $process" }
    }

    # 5. Ottimizzazioni Avanzate PC
    if ($Script:GlobalConfig.AdvancedOptimizations.EnablePCPerformance) {
        Write-Log -Level INFO -Message "[5/8] Applicazione ottimizzazioni PC avanzate..."
        if ($proctorProc) {
            $proctorProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High; Write-Log -Level SUCCESS "   - Priorità di '$($Script:GlobalConfig.ProctoringAppName)' impostata su 'Alta'."
            $gpuPrefKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"; Test-And-Create-RegistryPath -Path $gpuPrefKey | Out-Null
            Set-ItemProperty -Path $gpuPrefKey -Name $proctorProc.Path -Value "GpuPreference=2;"; Write-Log -Level SUCCESS "   - Prestazioni GPU per '$($Script:GlobalConfig.ProctoringAppName)' impostate su 'Elevate'."
        }
        $perfMask = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00); Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $perfMask -Type Binary
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFX" -Value 2; Write-Log -Level SUCCESS "   - Effetti visivi di Windows impostati per massime prestazioni."
    }

    # 6. Ottimizzazioni Avanzate Rete
    if ($Script:GlobalConfig.AdvancedOptimizations.EnableNetworkPerformance) {
        Write-Log -Level INFO -Message "[6/8] Applicazione ottimizzazioni Rete avanzate..."
        if ($proctorProc) {
            try { New-NetQosPolicy -Name "ExamPrepProctoring" -AppPathNameMatchCondition $proctorProc.Path -PriorityValue8021Action 7 -ErrorAction Stop; Write-Log -Level SUCCESS "   - Policy QoS creata per '$($Script:GlobalConfig.ProctoringAppName)'." }
            catch { Write-Log -Level WARN "   - Impossibile creare policy QoS." }
        }
        if ($backupData.Network.InterfaceGuid -and $Script:GlobalConfig.AdvancedOptimizations.DisableNagleAlgorithm) {
            $nagleKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($backupData.Network.InterfaceGuid)"
            Test-And-Create-RegistryPath -Path $nagleKeyPath | Out-Null; Set-ItemProperty -Path $nagleKeyPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force; Set-ItemProperty -Path $nagleKeyPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
            Write-Log -Level SUCCESS "   - Algoritmo di Nagle disabilitato."
        }
    }

    # 7. Ottimizzazioni Base
    Write-Log -Level INFO -Message "[7/8] Applicazione ottimizzazioni di base..."
    $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"; Test-And-Create-RegistryPath -Path $quietHoursKey | Out-Null; Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value 2 -Force; Write-Log -Level SUCCESS "   - Notifiche disattivate (Solo Sveglie)."
    $gameBarKey = "HKCU:\Software\Microsoft\GameBar"; Test-And-Create-RegistryPath -Path $gameBarKey | Out-Null; Set-ItemProperty -Path $gameBarKey -Name "AllowGameBar" -Value 0 -Type DWord -Force; Write-Log -Level SUCCESS "   - Xbox Game Bar disabilitata."
    try { powercfg /setactive "8c5e7fda-e8bf-4a96-9a8f-a307e2250669"; Write-Log -Level SUCCESS "   - Schema energetico impostato su 'Prestazioni elevate'." }
    catch { Write-Log -Level WARN "   - Impossibile impostare lo schema 'Prestazioni elevate' (potrebbe non essere disponibile)." }
    foreach ($s in $Script:GlobalConfig.ServicesToManage) { if ((Get-Service $s -EA SilentlyContinue).Status -eq 'Running') { Stop-Service $s -Force; Write-Log -Level SUCCESS "   - Servizio interrotto: $s" } }
    Get-Item -Path "$env:TEMP\*", "$env:SystemRoot\Temp\*", "$env:SystemRoot\Prefetch\*" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Log -Level SUCCESS "   - File temporanei puliti."

    # 8. Pulizia Cestino
    if ($Script:GlobalConfig.EmptyRecycleBin) { Write-Log -Level INFO -Message "[8/8] Pulizia del Cestino..."; try { (New-Object -ComObject Shell.Application).Namespace(10).Items() | ForEach-Object { $_.InvokeVerb("delete") }; Write-Log -Level SUCCESS "   - Cestino svuotato." } catch { Write-Log -Level WARN "   - Impossibile svuotare il Cestino." } }

    Write-Log -Level TITLE -Message "--- PREPARAZIONE COMPLETATA. In bocca al lupo! ---"
}

function Start-ExamRestore {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    $Script:GlobalLogPath = $LogPath
    Write-Log -Level TITLE -Message "--- MODALITÀ RIPRISTINO POST-ESAME v10.0 ---"
    $backupFile = Join-Path $env:TEMP "ExamPrepAdvancedBackup.json"
    if (-not (Test-Path $backupFile)) { Write-Log -Level ERROR "File di backup non trovato."; return }
    $backupData = Get-Content -Path $backupFile | ConvertFrom-Json
    if (-not $PSCmdlet.ShouldProcess("il sistema allo stato pre-esame", "Conferma ripristino", "Conferma")) { Write-Log -Level WARN "Ripristino annullato."; return }

    # 1. Ripristino Ottimizzazioni Avanzate
    Write-Log -Level INFO -Message "[1/3] Ripristino ottimizzazioni avanzate..."
    try {
        $Script:GlobalConfig = Get-ExamPrepConfig -ConfigPath $ConfigPath
        $proctorProc = Get-Process -Name $Script:GlobalConfig.ProctoringAppName.Replace(".exe", "") -ErrorAction SilentlyContinue
        if ($proctorProc -and $backupData.ProctorProcess.Priority) { $proctorProc.PriorityClass = $backupData.ProctorProcess.Priority; Write-Log -Level SUCCESS "   - Priorità CPU ripristinata." }
        if ($backupData.ProctorProcess.Path) {
            $gpuPrefKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
            if ($null -eq $backupData.ProctorProcess.GpuPreference) { Remove-ItemProperty -Path $gpuPrefKey -Name $backupData.ProctorProcess.Path -EA SilentlyContinue }
            else { Set-ItemProperty -Path $gpuPrefKey -Name $backupData.ProctorProcess.Path -Value $backupData.ProctorProcess.GpuPreference }
            Write-Log -Level SUCCESS "   - Prestazioni GPU ripristinate."
        }
        if ($null -ne $backupData.VisualEffects.UserPreferencesMask) {
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $backupData.VisualEffects.UserPreferencesMask -Type Binary
            $sig = '[DllImport("user32.dll")]public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
            (Add-Type -MemberDefinition $sig -Name "User32" -PassThru)::SystemParametersInfo(0x57, 0, $null, 2)
            Write-Log -Level SUCCESS "   - Effetti visivi ripristinati."
        }
        Remove-NetQosPolicy -Name "ExamPrepProctoring" -Confirm:$false -ErrorAction SilentlyContinue; Write-Log -Level SUCCESS "   - Policy QoS rimossa."
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
    Write-Log -Level INFO -Message "[2/3] Ripristino ottimizzazioni di base..."
    $quietHoursKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours"; Test-And-Create-RegistryPath -Path $quietHoursKey | Out-Null; $originalProfile = if($null -ne $backupData.QuietHours){$backupData.QuietHours}else{0}; Set-ItemProperty -Path $quietHoursKey -Name "QuietHoursProfile" -Value $originalProfile -Force; Write-Log -Level SUCCESS "   - Assistente notifiche ripristinato."
    $gameBarKey = "HKCU:\Software\Microsoft\GameBar"; Test-And-Create-RegistryPath -Path $gameBarKey | Out-Null; $originalGameBar = if($null -ne $backupData.GameBar.AllowGameBar){$backupData.GameBar.AllowGameBar}else{1}; Set-ItemProperty -Path $gameBarKey -Name "AllowGameBar" -Value $originalGameBar -Type DWord -Force; Write-Log -Level SUCCESS "   - Xbox Game Bar ripristinata."
    powercfg /setactive $backupData.PowerScheme; Write-Log -Level SUCCESS "   - Schema energetico ripristinato."
    foreach ($s in $backupData.Services.PSObject.Properties) { if ($s.Value -eq 'Running') { Start-Service -Name $s.Name -EA SilentlyContinue; Write-Log -Level SUCCESS "   - Servizio riavviato: $($s.Name)" } }

    # 3. Pulizia
    Write-Log -Level INFO -Message "[3/3] Pulizia file di backup..."
    Remove-Item -Path $backupFile -Force; Write-Log -Level SUCCESS "   - File di backup rimosso."

    Write-Log -Level TITLE -Message "--- RIPRISTINO COMPLETATO. Ben fatto! ---"
}

Export-ModuleMember -Function Start-ExamPreparation, Start-ExamRestore
# --- FINE MODULO POWERSHELL ExamPrep ---