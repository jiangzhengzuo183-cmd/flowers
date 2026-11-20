@echo off
chcp 65001 >nul
set "PROJECT=%~dp0"
set "ENGINE=%PROJECT%..\flowers-bakery-integration\.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
if exist "%PROJECT%.tools\godot\Godot_v4.7.2-stable_win64_console.exe" set "ENGINE=%PROJECT%.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
"%ENGINE%" --path "%PROJECT%godot" --resolution 1600x900 --script res://tests/preview_native_report_book.gd
