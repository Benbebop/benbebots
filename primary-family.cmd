@echo off
cd scr

title FAMILY GUY

cls

:autorestart

luvit errorcatch.lua bot-family.lua 2> %LOCALAPPDATA%\benbebot\errorhandle\error-family.proxy

type %LOCALAPPDATA%\benbebot\errorhandle\error-family.proxy > %LOCALAPPDATA%\benbebot\errorhandle\error-family.log

goto autorestart