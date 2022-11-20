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

function srcds.getJoinUrl()
	if not joinString then return false end
	return "steam://run/4000//" .. querystring.urlencode("+" .. joinString)
end

function srcds.killServer()
	if proc then proc:kill() end
end

local gamemodeIndex = {sandbox = 0}

function srcds.launch( gamemode, exitCallback )
	
	if not gamemodeIndex[gamemode] then return false, "gamemode does not exist" end
	
	if proc then return false end
	
	local initThread, pipeThread
	initThread = coroutine.running()
	
	proc = uv.spawn(gmodDirectory .. "SrcdsConRedirect.exe", {
		stdio = {stdin, stdout, stderr}, 
		args = {"+maxplayers", "20", "-console", "+gamemode", gamemode, "+map", "gm_construct", "-p2p"}, 
		verbatim = true
	}, function( ... ) if onExit then onExit( ... ) end resetVariables() end)
	
	-- WAIT FOR P2P ID --
	
	local p2pMessage
	
	stdout:read_start( function(err, data)
		if err or not data then return end
		
		p2pMessage = data:match("`(connect.-)`")
		if p2pMessage then coroutine.resume(initThread) end
	end )
	
	-- WAIT FOR PSEUDOPIPE --
	
	--[[local pipeDir = gmodDirectory .. "garrysmod/data/pseudopipe/"
	
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
	end)]]
	
	function onExit() stdout:read_stop() --[[file_event:stop()]] coroutine.resume( initThread or pipeThread ) end
	
	coroutine.yield()
	initThread = nil
	
	-- RECIEVED P2P ID --
	
	if not p2pMessage then return false, "couldn't locate p2p message" end --couldnt get p2p message for some reason
	
	joinString = p2pMessage
	
	--[[if not pipeThread then 
		pipeThread = coroutine.running()
		coroutine.yield()
	end
	pipeThread = nil
	
	if pstdin and pstdout and pstderr then else
		return false, "couldnt connect pseudopipes"
	end]]
	
	-- RECIEVED PSTDIO --
	
	onExit = function() coroutine.wrap(exitCallback)() end
	
	return true
	
end

return srcds