set ERRORDIR=%TEMP%\benbebots\logs

cd ..

if not exist %1.lua (
	echo %1.lua does not exist
	pause
	goto end
)

mkdir %ERRORDIR% 2>nul

:restart

luvit %1.lua 2> %ERRORDIR%\err_%1.prox.log

::type %ERRORDIR%\out_%1.prox.log > %ERRORDIR%\out_%1.log
type %ERRORDIR%\err_%1.prox.log > %ERRORDIR%\err_%1.log

pause

goto restart

:end