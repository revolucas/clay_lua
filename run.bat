@echo off
setlocal
cd /d "%~dp0"
set "LUAJIT=%LUAJIT%"

if "%LUAJIT%"=="" set "LUAJIT=luajit.exe"
"%LUAJIT%" main.lua

