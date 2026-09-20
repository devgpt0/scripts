@echo off
setlocal
rem This launcher bypasses the current PowerShell execution policy for this run only.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0remove-target-repos.ps1" %*
exit /b %ERRORLEVEL%
