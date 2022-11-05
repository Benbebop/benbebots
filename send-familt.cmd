@echo off
cd scr

title Benbebot-GUI

cls

::start luvit bot-read.lua

:autorestart

luvit bot-send.lua 20

goto autorestart