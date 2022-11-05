@echo off
cd scr

title Benbebot-VoiceChannel-Pipe

cls

:autorestart

luvit errorcatch.lua bot-connect.lua 20 2> %LOCALAPPDATA%\benbebot\errorhandle\error-vc.proxy

type %LOCALAPPDATA%\benbebot\errorhandle\error-vc.proxy > %LOCALAPPDATA%\benbebot\errorhandle\error-vc.log

goto autorestart