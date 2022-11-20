local uv, fs, timer, querystring = require("uv"), require("fs"), require("timer"), require("querystring")

local stdin, stdout, stderr, file_event = uv.new_pipe(), uv.new_pipe(), uv.new_pipe(), uv.new_fs_event()
local pstdin, pstdout, pstderr
local proc, onExit, joinString

local gmodDirectory = ""

local function resetVariables()
	pstdin, pstdout, pstderr, proc, onExit, joinString = nil
end

local srcds = {}

function srcds.setDirectory( dir ) gmodDirectory = dir end

function srcds.launch( gamemode, exitCallback )
	
	print("test")
	
	if proc then return false end
	
	local initThread, pipeThread
	initThread = coroutine.running()
	
	proc = uv.spawn(gmodDirectory .. "SrcdsConRedirect.exe", {
		stdio = {stdin, stdout, stderr}, 
		args = {"+maxplayers", "20", "-console", "+gamemode", gamemode, "+map", "gm_construct", "-p2p"}, 
		verbatim = true
	}, function( ... ) if onExit then onExit( ... ) end resetVariables() end)
	
	-- WAIT FOR P2P ID --
	
	local inMessage, message = false, ""
	
	local func = function(err, data)
		print("test")
		if err or not data then return end
		
		if inMessage then
			local fin = data:find("\r\n%-+")
			if fin then 
				message = message .. data:sub(1, fin)
				--stdout:read_stop()
				coroutine.resume( initThread )
				print("attempted to resume first yield")
			else
				message = message .. data
			end
		else
			local _, start = data:find("%-+ Steam P2P %-+%s*")
			if start then
				inMessage = true
				message = data:sub(start, -1)
				print("recieved p2p header")
				func()
			end
		end
	end
	
	stdout:read_start( func )
	
	-- WAIT FOR PSEUDOPIPE --
	
	local pipeDir = gmodDirectory .. "garrysmod/data/pseudopipe/"
	
	file_event:start(pipeDir, {}, function(err, filename, events)
		if events.changed then
			if filename == "pipe_0.dat" then
				pstdin = pipeDir .. filename
			elseif filename == "pipe_1.dat" then
				pstdout = pipeDir .. filename
			elseif filename == "pipe_2.dat" then
				pstderr = pipeDir .. filename
			end
			if pstdin and pstdout and pstderr then
				if pipeThread then
					coroutine.resume( pipeThread )
					print("attempted to resume second yield")
				else
					pipeThread = true
				end
				file_event:stop()
			end
		end
	end)
	
	function onExit() stdout:read_stop() file_event:stop() print("attempted to resume first or second yield") coroutine.resume( initThread or pipeThread ) end
	
	coroutine.yield()
	initThread = nil
	
	print("first yield complete")
	
	-- RECIEVED P2P ID --
	
	if not message then return false, "couldn't locate p2p message" end --couldnt get p2p message for some reason
	
	local str = message:match("`(.-)`")
	if not str then return false, "p2p message does not contain command" end -- p2p message didnt contain the command for some reason
	
	joinString = querystring.urlencode(str)
	
	if not pipeThread then 
		pipeThread = coroutine.running()
		coroutine.yield()
	end
	pipeThread = nil
	
	print("second yield complete")
	
	if pstdin and pstdout and pstderr then else
		return false, "couldnt connect pseudopipes"
	end
	
	-- RECIEVED PSTDIO --
	
	onExit = exitCallback
	
	return true
	
end

return srcds