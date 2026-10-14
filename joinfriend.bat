@echo off
set USERID=4263338465
if not "%~1"=="" set USERID=%~1
taskkill /im RobloxPlayerBeta.exe /f >nul 2>&1
timeout /t 2 /nobreak >nul
start "" "roblox://experiences/start?userId=%USERID%"
