set ERRORDIR=%TEMP%\benbebots\logs

cd ..

if not exist %1.lua (
	echo %1.lua does not exist
	goto end
)

mkdir %ERRORDIR% 2>nul

:restart

luvit errorcatch.lua %1.lua 2> %ERRORDIR%\err_%1.prox.log

type %ERRORDIR%\err_%1.prox.log > %ERRORDIR%\err_%1.log

timeout /T 1 /NOBREAK

if errorlevel 1 (goto end)

goto restart

:end

pause