@echo off
rem Double-click to open the winopt menu as admin.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winopt.ps1" menu -Elevate
