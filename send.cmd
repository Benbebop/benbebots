@echo off
cd scr

title Benbebot-GUI

cls

:autorestart

luvit bot-send.lua 1

goto autorestart