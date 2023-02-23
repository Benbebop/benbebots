local uv, fs, json, timer = require("uv"), require("fs"), require("json"), require("timer")
local discordia = require("discordia")

local gamemodes = json.parse(fs.readFileSync("resource/gamemodes.json"))
assert(gamemodes, "failed to parse gamemode json")

local function insertArg( tbl, arg, value ) table.insert(tbl, tostring(arg)) table.insert(tbl, tostring(value)) end

local gms, get, set = discordia.class("GarrysmodServer")

function gms:__init( directory )
	self._dir = directory
end

function gms:setToken( token )
	self._gslt = token
end

-- cooler way of doing it but it doesnt work
--[[function gms:start( gamemode, map )
	self._gamemode, self._map = gamemode, map
	
	self._waitingForServer = {}
	
	-- source, the quirky bastard, needs special little things for getting con output. shout out Megalan https://web.archive.org/web/20160811192923/https://facepunch.com/showthread.php?t=1181915
	self._hfile, self._hparent, self._hchild = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
	self._hfilebuff, self._hparentbuff, self._hchildbuff = {}, {}, {}
	local args = {"-console",
		"-HFILE", self._hfile:fileno(), "-HPARENT", self._hparent:fileno(), "-HCHILD", self._hchild:fileno(),
		"+gamemode", self._gamemode, "+map", self._map or "gm_construct", 
	}
	
	if self._gslt then insertArg(args, "+sv_setsteamaccount", self._gslt) end
	
	table.insert(args, "-p2p")
	
	self._proc = uv.spawn(self._dir .. "srcds.exe", {stdio = {0, 1, 2}, args = args}, function()
		self._hfile:shutdown() self._hparent:shutdown() self._hchild:shutdown()
		
		for _,v in ipairs(self._waitingForServer) do coroutine.resume(v, nil, "program exited") end
		self._waitingForServer = nil
	end)
	
	self._hfile:read_start(function(err, chunk)
		if err then
			error("HFILEREADERROR: " .. err)
		elseif chunk then
			p("HFILE", chunk)
			table.insert(self._hfilebuff, chunk)
		else
			self._hfilebuff = nil
		end
	end)
	
	self._hparent:read_start(function(err, chunk)
		if err then
			error("HPARENTREADERROR: " .. err)
		elseif chunk then
			p("HPARENT", chunk)
			table.insert(self._hparentbuff, chunk)
		else
			self._hparentbuff = nil
		end
	end)
	
	self._hchild:read_start(function(err, chunk)
		if err then
			error("HCHILDREADERROR: " .. err)
		elseif chunk then
			p("HCHILD", chunk)
			table.insert(self._hchildbuff, chunk)
		else
			self._hchildbuff = nil
		end
	end)
end]]

function gms:start( gm, map )
	gm = gm:lower()
	self._waitingForServer = {}
	
	-- get gamemode --
	local gamemode
	for _,v in ipairs(gamemodes) do
		if string.match(gm, v.pattern) then
			gamemode = v
			break
		end
	end
	if not gamemode then return nil, "invalid gamemode" end
	
	-- create args --
	local args = {"-console", "+gamemode", gamemode.gamemode, "+map", map or gamemode.default_map or "gm_construct"}
	if gamemode.collection then insertArg(args, "+host_workshop_collection", gamemode.collection) end
	if self._gslt then insertArg(args, "+sv_setsteamaccount", self._gslt) end
	table.insert(args, "-p2p")
	
	-- spawn process --
	local stdin, stdout, stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
	self._proc = uv.spawn(uv.cwd() .. "\\bin\\srcdspipe.exe", {stdio = {stdin, stdout, stderr}, cwd = self._dir, args = args}, function()
		if self._waitingForServer then
			local err = self._errbuff[1] and table.concat(self._errbuff)
			for _,v in ipairs(self._waitingForServer) do coroutine.resume(v, nil, err or "server closed") end
		end
	end)
	
	self._outbuff, self._errbuff = {}, {}
	
	stdout:read_start(function(err, chunk)
		assert(not err, err)
		if not chunk then return end
		table.insert(self._outbuff, chunk)
		if not self._waitingForServer then return end
		local joinStr = table.concat(self._outbuff):match("%-%sSteam%sP2P%s%-.-`(.-)`")
		if not joinStr then return end
		for _,v in ipairs(self._waitingForServer) do coroutine.resume(v, joinStr) end
		self._waitingForServer = nil
	end)
	
	stderr:read_start(function(err, chunk)
		assert(not err, err)
		if not chunk then return end
		table.insert(self._errbuff, chunk)
	end)
	
	return gamemode
end

function gms:waitForServer( timeout )
	if self._joinString then return self._joinString end
	local running = coroutine.running()
	table.insert(self._waitingForServer, running)
	local t = timer.setTimeout(timeout * 1000, function() coroutine.resume( running, nil, "server start timed out" ) end)
	local r = coroutine.yield()
	timer.clearTimeout(t)
	return r
end

function gms:getConsole()
	return self._outbuff and table.concat(self._outbuff)
end

function gms:kill()
	
end

return gms