@echo off
title Barony Save Protector
color 0B

echo =============================================================
echo   ___    _    ___   ___   _  _ __   __
echo  ^| _ )  / \  ^| _ \ / _ \ ^| \^| ^|\ \ / /
echo  ^| _ \ / _ \ ^|   /^| (_) ^|^| .` ^| \ V / 
echo  ^|___//_/ \_\^|_^|_\ \___/ ^|_^|\_^|  ^|_^|  
echo         S A V E   P R O T E C T O R
echo                                     Created by: Raven Lord
echo =============================================================
echo  [SYSTEM] Auto-Restore is enabled.
echo  [SYSTEM] Steam Cloud bypass is active.
echo  [SYSTEM] Graveyard Staging is running.
echo.
echo  [!] Please DO NOT CLOSE this window while playing. 
echo  [!] It will automatically close when you exit Barony.
echo =============================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0barony_backup.ps1" %*
