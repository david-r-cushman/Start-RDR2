@echo off
REM Double-click this file to launch RDR2 and leave the result visible.
REM The script path must be quoted by itself; -KeepWindowOpen is a separate
REM PowerShell argument, not part of the file name.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-RDR2.ps1" -KeepWindowOpen %*
