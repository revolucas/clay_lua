@echo off
setlocal
cd /d "%~dp0"
set "LUAJIT=%LUAJIT%"

if "%LUAJIT%"=="" set "LUAJIT=bin/x64/luajit.exe"
"%LUAJIT%" main.lua

