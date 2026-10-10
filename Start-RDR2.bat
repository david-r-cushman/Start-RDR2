@echo off
REM Double-click this file to launch RDR2 and enable Efficiency Mode.
REM Use Start-RDR2-Keep-Window-Open.bat for visual confirmation instead.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-RDR2.ps1" %*
