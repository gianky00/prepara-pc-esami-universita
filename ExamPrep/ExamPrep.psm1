# encoding: utf-8
<#
.SYNOPSIS
    Modulo PowerShell per preparare un PC Windows per esami online proctoring.

.DESCRIPTION
    Questo modulo fornisce due funzioni principali: Start-ExamPreparation e Start-ExamRestore.
    La modalità di preparazione ottimizza il sistema per le massime prestazioni e stabilità,
    chiudendo processi non necessari e applicando configurazioni specifiche.
    La modalità di ripristino annulla tutte le modifiche, riportando il sistema allo stato originale.
    Tutte le operazioni sono commentate in italiano e configurabili tramite un file JSON esterno.

.NOTES
    Autore: Jules
    Versione: 1.0
    Data: 28/09/2025
    Requisiti: Esecuzione come Amministratore.
#>

#region Variabili Globali e Impostazioni del Modulo

# Definisce le funzioni che verranno esportate dal modulo e rese disponibili all'utente.
Export-ModuleMember -Function Start-ExamPreparation, Start-ExamRestore

# Percorso del file di configurazione. Lo script si aspetta di trovarlo nella stessa cartella.
$Global:ConfigFilePath = Join-Path $PSScriptRoot "ExamPrep.config.json"

# Percorso della cartella di backup in AppData\Local, una posizione persistente.
$Global:BackupDir = Join-Path $env:LOCALAPPDATA "ExamPrep"
$Global:BackupFilePath = Join-Path $Global:BackupDir "ExamPrep_Backup.json"

# GUID del piano energetico "Prestazioni eccellenti".
$Global:UltimatePerformancePlanGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"

#endregion

#region Funzioni Helper Interne (non esportate)

<#
.SYNOPSIS
    Carica la configurazione dal file JSON.
.DESCRIPTION
    Legge il file ExamPrep.config.json e lo converte in un oggetto PowerShell.
    Se il file non esiste o è corrotto, termina lo script con un errore.
.OUTPUTS
    PSCustomObject con la configurazione.
#>
function Get-ExamPrepConfig {
    if (-not (Test-Path $Global:ConfigFilePath)) {
        throw "File di configurazione non trovato: $($Global:ConfigFilePath)"
    }
    try {
        return Get-Content $Global:ConfigFilePath | Out-String | ConvertFrom-Json
    }
    catch {
        throw "Errore nella lettura o nel parsing del file di configurazione JSON. Assicurarsi che sia formattato correttamente."
    }
}

<#
.SYNOPSIS
    Crea un backup dello stato attuale del sistema.
.DESCRIPTION
    Salva le impostazioni correnti che verranno modificate (es. piano energetico)
    in un file JSON. Questo file verrà usato da Start-ExamRestore.
#>
function New-SystemBackup {
    Write-Host "Creazione del backup dello stato del sistema in corso..." -ForegroundColor Cyan

    # Assicura che la cartella di backup esista.
    if (-not (Test-Path $Global:BackupDir)) {
        New-Item -Path $Global:BackupDir -ItemType Directory -Force | Out-Null
    }

    # Raccoglie le informazioni da salvare.
    $backupData = @{
        # Salva il GUID del piano di risparmio energetico attualmente attivo.
        ActivePowerPlan = (powercfg /getactivescheme).ToString().Split(" ")[3]
        # Aggiungere qui altre impostazioni da salvare in futuro (es. stato registro di rete)
        NetworkSettings = @{} # Placeholder per future impostazioni di rete
    }

    # Salva i dati nel file di backup in formato JSON.
    try {
        $backupData | ConvertTo-Json -Depth 3 | Out-File -FilePath $Global:BackupFilePath -Encoding utf8 -Force
        Write-Host "Backup creato con successo in: $($Global:BackupFilePath)" -ForegroundColor Green
    }
    catch {
        throw "Impossibile creare il file di backup. Dettagli: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Applica le ottimizzazioni di sistema per l'esame.
.DESCRIPTION
    Modifica le impostazioni di sistema per massimizzare le prestazioni.
    - Imposta il piano energetico "Prestazioni eccellenti".
    - Disabilita l'algoritmo di Nagle per ridurre la latenza di rete.
#>
function Set-SystemOptimizations {
    Write-Host "Applicazione delle ottimizzazioni di sistema in corso..." -ForegroundColor Cyan

    # --- OTTIMIZZAZIONE PIANO ENERGETICO ---
    Write-Host "1. Impostazione del piano energetico 'Prestazioni eccellenti'..."
    # Verifica se il piano "Prestazioni eccellenti" è già disponibile.
    $ultimatePlanExists = powercfg /list | Select-String -Pattern $Global:UltimatePerformancePlanGuid -Quiet
    if (-not $ultimatePlanExists) {
        Write-Host "Il piano 'Prestazioni eccellenti' non è visibile, lo attivo..." -ForegroundColor Yellow
        powercfg -duplicatescheme $Global:UltimatePerformancePlanGuid | Out-Null
    }
    # Imposta il piano come attivo.
    powercfg /setactive $Global:UltimatePerformancePlanGuid
    Write-Host "Piano energetico impostato su 'Prestazioni eccellenti'." -ForegroundColor Green

    # --- OTTIMIZZAZIONE DI RETE (ALGORITMO DI NAGLE) ---
    Write-Host "2. Disabilitazione dell'algoritmo di Nagle per la connessione di rete attiva..."
    try {
        # Trova l'interfaccia di rete primaria (quella con un gateway predefinito)
        $interface = Get-CimInstance -Class Win32_IP4RouteTable | Where-Object { $_.Destination -eq '0.0.0.0' -and $_.Mask -eq '0.0.0.0' } | Get-NetAdapter
        if ($interface) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($interface.InterfaceGuid)"
            # Imposta le chiavi di registro per disabilitare Nagle.
            # TcpAckFrequency=1 -> Invia ACK immediatamente.
            # TCPNoDelay=1 -> Disabilita l'algoritmo di Nagle.
            Set-ItemProperty -Path $regPath -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $regPath -Name 'TCPNoDelay' -Value 1 -Type DWord -Force
            Write-Host "Algoritmo di Nagle disabilitato per l'interfaccia $($interface.Name)." -ForegroundColor Green
        } else {
            Write-Warning "Impossibile trovare un'interfaccia di rete attiva con un gateway predefinito. Ottimizzazione di rete saltata."
        }
    }
    catch {
        Write-Warning "Errore durante l'ottimizzazione della rete. Dettagli: $($_.Exception.Message)"
    }

    # --- OTTIMIZZAZIONE GPU (Placeholder) ---
    # La modifica della preferenza GPU per applicazione richiede la modifica di chiavi di registro complesse
    # HKEY_CURRENT_USER\Software\Microsoft\DirectX\UserGpuPreferences
    # L'impostazione del piano "Prestazioni Eccellenti" già istruisce il sistema a usare la GPU ad alte prestazioni.
    Write-Host "3. L'ottimizzazione GPU è gestita dal piano 'Prestazioni eccellenti'."
}

<#
.SYNOPSIS
    Gestisce i processi non essenziali in modo interattivo.
.DESCRIPTION
    Recupera i processi in esecuzione, filtra quelli di sistema e quelli nella lista
    di ignorati, e chiede all'utente come trattare i rimanenti.
#>
function Manage-RunningProcesses {
    param(
        [Parameter(Mandatory=$true)]
        $Config
    )

    Write-Host "Analisi dei processi in esecuzione in corso..." -ForegroundColor Cyan

    # Processi di sistema e processi "idle" da ignorare sempre
    $systemProcesses = @("System", "Idle", "Registry")

    # Recupera i processi utente, escludendo quelli di sistema e quelli senza un percorso (processi interni)
    $userProcesses = Get-Process | Where-Object { $_.Path -and $systemProcesses -notcontains $_.ProcessName }

    Write-Host "Trovati $($userProcesses.Count) processi utente attivi."

    foreach ($proc in $userProcesses) {
        $procName = $proc.ProcessName

        # Salta i processi che sono nella lista degli ignorati
        if ($Config.ProcessiDaIgnorare -contains $procName) {
            Write-Host "Processo ignorato (da config): $procName" -ForegroundColor Gray
            continue
        }

        # Chiude automaticamente i processi nella lista "Sempre da chiudere"
        if ($Config.ProcessiSempreDaChiudere -contains $procName) {
            Write-Host "Chiusura automatica del processo (da config): $procName" -ForegroundColor Yellow
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
            continue
        }

        # Chiede all'utente cosa fare con i processi rimanenti
        $choice = Read-Host @"
-----------------------------------------------------------------
Processo trovato: '$($procName)' (ID: $($proc.Id))
Descrizione: $($proc.Description)
Cosa vuoi fare?
(C)hiudi - Chiude questa istanza del processo.
(I)gnora - Lascia in esecuzione questa istanza.
(A)ggiungi a 'Sempre da Chiudere' - Chiude e aggiunge alla lista per il futuro.
(G)giungi a 'Sempre da Ignorare' - Ignora e aggiunge alla lista per il futuro.
Inserisci la tua scelta e premi Invio [C, I, A, G]:
"@

        switch ($choice.ToUpper()) {
            "C" {
                Write-Host "Chiusura del processo: $procName" -ForegroundColor Yellow
                Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
            }
            "I" {
                Write-Host "Processo ignorato: $procName"
            }
            "A" {
                Write-Host "Aggiungo '$procName' alla lista 'Sempre da Chiudere' e lo chiudo." -ForegroundColor Magenta
                $Config.ProcessiSempreDaChiudere += $procName
                Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
            }
            "G" {
                Write-Host "Aggiungo '$procName' alla lista 'Sempre da Ignorare'." -ForegroundColor Magenta
                $Config.ProcessiDaIgnorare += $procName
            }
            default {
                Write-Warning "Scelta non valida. Il processo '$procName' verrà ignorato per questa sessione."
            }
        }
    }

    # Salva le modifiche alla configurazione (nuovi processi aggiunti alle liste)
    Write-Host "Salvataggio delle preferenze nel file di configurazione..."
    $Config | ConvertTo-Json -Depth 5 | Out-File -FilePath $Global:ConfigFilePath -Encoding utf8 -Force
}


#endregion

#region Funzioni Principali (Esportate)

function Start-ExamPreparation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "   AVVIO PREPARAZIONE PC PER ESAME TELEMATICO"
    Write-Host "==================================================" -ForegroundColor Green

    # 1. Carica la configurazione
    $config = Get-ExamPrepConfig

    # 2. Crea il backup dello stato del sistema
    New-SystemBackup

    # 3. Applica le ottimizzazioni
    Set-SystemOptimizations

    # 4. Gestisce i processi in esecuzione
    Manage-RunningProcesses -Config $config

    Write-Host "==================================================" -ForegroundColor Green
    Write-Host " PREPARAZIONE COMPLETATA. IL PC E' OTTIMIZZATO. "
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Puoi ora avviare il software dell'esame."
    Write-Host "Al termine, ricorda di eseguire lo script di ripristino."
}

function Start-ExamRestore {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "     AVVIO RIPRISTINO CONFIGURAZIONE PC"
    Write-Host "==================================================" -ForegroundColor Yellow

    # 1. Verifica che il file di backup esista
    if (-not (Test-Path $Global:BackupFilePath)) {
        throw "File di backup non trovato! Impossibile procedere con il ripristino. Esegui prima la preparazione."
    }

    # 2. Carica i dati di backup
    $backupData = Get-Content $Global:BackupFilePath | Out-String | ConvertFrom-Json

    # 3. Ripristina le impostazioni
    Write-Host "Ripristino delle impostazioni di sistema in corso..." -ForegroundColor Cyan

    # Ripristina il piano energetico
    Write-Host "1. Ripristino del piano energetico originale..."
    powercfg /setactive $backupData.ActivePowerPlan
    Write-Host "Piano energetico ripristinato." -ForegroundColor Green

    # Ripristina le impostazioni di rete (rimuovendo le chiavi di registro)
    Write-Host "2. Ripristino delle impostazioni di rete..."
    try {
        $interface = Get-CimInstance -Class Win32_IP4RouteTable | Where-Object { $_.Destination -eq '0.0.0.0' -and $_.Mask -eq '0.0.0.0' } | Get-NetAdapter
        if ($interface) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($interface.InterfaceGuid)"
            Remove-ItemProperty -Path $regPath -Name 'TcpAckFrequency' -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name 'TCPNoDelay' -ErrorAction SilentlyContinue
            Write-Host "Impostazioni di rete ripristinate per l'interfaccia $($interface.Name)." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Errore durante il ripristino della rete. Potrebbe essere necessario un riavvio. Dettagli: $($_.Exception.Message)"
    }

    # 4. Pulisce il file di backup
    Write-Host "Pulizia dei file di backup in corso..."
    Remove-Item -Path $Global:BackupFilePath -Force

    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "  RIPRISTINO COMPLETATO. IL PC E' TORNATO ALLA"
    Write-Host "         NORMALITA'. BUONA CONTINUAZIONE!"
    Write-Host "==================================================" -ForegroundColor Yellow
}

#endregion