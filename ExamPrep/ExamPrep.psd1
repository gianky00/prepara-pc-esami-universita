@{
#
# File Manifesto del Modulo per ExamPrep
#
# Autore: Jules
# Versione: 1.0
# Data: 28/09/2025
#

# Specifica la versione del modulo. Utile per la gestione delle versioni.
ModuleVersion = '1.0.0'

# Un identificatore univoco per il modulo.
GUID = 'a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890'

# L'autore del modulo.
Author = 'Jules'

# Il nome dell'azienda o del creatore.
CompanyName = 'N/A'

# Copyright.
Copyright = "(c) 2025 Jules. Tutti i diritti riservati."

# Descrizione dello scopo del modulo.
Description = "Modulo PowerShell per preparare un PC Windows per esami telematici, ottimizzando le prestazioni e riducendo le interruzioni. Include funzioni per la preparazione e il ripristino del sistema."

# Specifica il file di script principale (.psm1) o il file binario (.dll) del modulo.
RootModule = 'ExamPrep.psm1'

# Elenca le funzioni che questo modulo esporta. Solo queste saranno visibili all'utente.
# È una buona pratica specificarle esplicitamente per evitare di esporre funzioni helper interne.
FunctionsToExport = @(
    'Start-ExamPreparation',
    'Start-ExamRestore'
)

# Elenca i cmdlet che questo modulo esporta.
CmdletsToExport = @()

# Elenca le variabili che questo modulo esporta.
VariablesToExport = '*'

# Elenca gli alias che questo modulo esporta.
AliasesToExport = @()

# Requisiti minimi per l'esecuzione del modulo.
# PowerShellVersion = '5.1'
# CLRVersion = '4.0'

}