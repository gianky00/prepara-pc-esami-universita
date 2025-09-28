@echo off
:: =================================================================
::  GENERATORE DI REPORT DI SISTEMA
:: =================================================================
::  Questo script raccoglie informazioni dettagliate su hardware,
::  software e rete e le salva in un file di testo.
:: =================================================================

set "reportFile=%~dp0Report_PC.txt"

echo [INFO] Creazione del report di sistema in corso...
echo        Questa operazione potrebbe richiedere alcuni secondi.

(
    echo =================================================================
    echo                 REPORT DI SISTEMA - %date% %time%
    echo =================================================================
    echo.
    echo.

    echo --- INFORMAZIONI DI SISTEMA (SYSTEMINFO) ---
    systeminfo
    echo.
    echo.

    echo --- INFORMAZIONI PROCESSORE (WMIC CPU) ---
    wmic cpu get Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed /format:list
    echo.
    echo.

    echo --- INFORMAZIONI SCHEDA VIDEO (WMIC GPU) ---
    wmic path win32_videocontroller get Name, DriverVersion, AdapterRAM /format:list
    echo.
    echo.

    echo --- INFORMAZIONI MEMORIA RAM (WMIC MEMORY) ---
    wmic MemoryChip get BankLabel, Capacity, MemoryType, Speed /format:list
    echo.
    echo.

    echo --- INFORMAZIONI DISCHI FISICI (WMIC DISKDRIVE) ---
    wmic diskdrive get Model, Size, InterfaceType /format:list
    echo.
    echo.

    echo --- CONFIGURAZIONE DI RETE (IPCONFIG) ---
    ipconfig /all
    echo.
    echo.

    echo --- PIANI DI RISPARMIO ENERGETICO (POWERCFG) ---
    powercfg /list
    echo.
    echo.

    echo =================================================================
    echo                      FINE DEL REPORT
    echo =================================================================

) > "%reportFile%"

echo.
echo [SUCCESS] Report creato con successo!
echo           Il file "%reportFile%" verra' ora aperto...

timeout /t 2 >nul
start notepad "%reportFile%"

exit