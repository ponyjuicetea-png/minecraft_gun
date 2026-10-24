@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch.ps1" -Mode Server
if errorlevel 1 pause
