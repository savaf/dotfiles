@echo off
rem Lanzador de bootstrap-windows.ps1 que evita el error de "running scripts is
rem disabled on this system": pasa -ExecutionPolicy Bypass solo a este proceso,
rem sin tocar la politica del sistema. Uso: scripts\bootstrap-windows.cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap-windows.ps1" %*
exit /b %ERRORLEVEL%
