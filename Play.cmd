@echo off
setlocal
set "PIPE_GODOT="
for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do (
  if exist "%%~fD\Godot_v4.7-stable_win64.exe" set "PIPE_GODOT=%%~fD\Godot_v4.7-stable_win64.exe"
)
if not defined PIPE_GODOT for /f "delims=" %%G in ('where Godot_v4.7-stable_win64.exe 2^>nul') do set "PIPE_GODOT=%%G"
if not defined PIPE_GODOT (
  echo Godot 4.7 was not found. Open project.godot in Godot 4.7 and press F5,
  echo or add the Godot executable to PATH.
  pause
  exit /b 1
)
start "" "%PIPE_GODOT%" --path "%~dp0"