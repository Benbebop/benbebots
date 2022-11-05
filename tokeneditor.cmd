@echo off
cd scr

for /f "skip=1 delims=" %%A in (
  'wmic computersystem get name'
) do for /f "delims=" %%B in ("%%A") do set "compName=%%A"

if "%compName%"=="" (
	echo it is not recommended to run this program on the main server
	pause
    exit
)

title Token Editor

lua53.exe tokenedit.lua