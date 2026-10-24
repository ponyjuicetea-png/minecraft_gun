@echo off
setlocal
if exist "%~dp0dist\Frontline.exe" (
    start "" /d "%~dp0dist" "%~dp0dist\Frontline.exe" %*
    exit /b 0
)
if exist "%~dp0runtime\godot.windows.editor.x86_64.exe" (
    start "" /d "%~dp0game" "%~dp0runtime\godot.windows.editor.x86_64.exe" --path "%~dp0game" %*
    exit /b 0
)
echo Frontline executable is missing. Extract the full standalone package first.
pause
exit /b 1
