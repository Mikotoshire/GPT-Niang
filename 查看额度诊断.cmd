@echo off
chcp 65001 >nul
node "%~dp0gpt-niang-usage\runtime\control.mjs" diagnostics 100
pause
