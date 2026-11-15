@echo off
REM Builds a quick test APK (no ads plugin needed). Edit the next line so it points to your Godot 4.7.2 exe.
set GODOT="C:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist %GODOT% (
  echo Godot not found at %GODOT% - open this file in Notepad and fix the path.
  pause
  exit /b 1
)
echo Importing project (first time takes a few minutes)...
%GODOT% --headless --path "%~dp0." --import
echo Building APK...
%GODOT% --headless --path "%~dp0." --export-debug "Android APK (quick test, no ads)" "%~dp0build\mystery_box_quick.apk"
if exist "%~dp0build\mystery_box_quick.apk" (echo DONE: build\mystery_box_quick.apk) else (echo FAILED - copy the red error text above and send it.)
pause
