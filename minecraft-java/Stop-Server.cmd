@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch.ps1" -Mode Stop
if errorlevel 1 pause
