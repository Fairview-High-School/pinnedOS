@echo off
REM Launches the PowerShell script that downloads the latest Ubuntu LTS ISO
REM and verifies its checksum. Assumes get-ubuntu-lts.ps1 is in the same folder.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0get-ubuntu-lts.ps1"
pause