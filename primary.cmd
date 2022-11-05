@echo off
cd scr

set ERRDIR="%LOCALAPPDATA%\benbebot\errorhandle"

title Benbebot

cls

:autorestart

luvit errorcatch.lua bot.lua 2> %ERRDIR%\error.proxy

type %ERRDIR%\error.proxy > %ERRDIR%\error.log

goto autorestart