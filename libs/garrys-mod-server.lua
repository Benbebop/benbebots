local uv, fs, json, timer, readline, appdata = require("uv"), require("fs"), require("json"), require("timer"), require("readline"), require("appdata")
local discordia = require("discordia")

local Emitter = discordia.class.classes.Emitter

local gamemodes = json.parse(fs.readFileSync("resource/gamemodes.json"))
assert(gamemodes, "failed to parse gamemode json")

local function insertArg( tbl, arg, value ) table.insert(tbl, tostring(arg)) table.insert(tbl, tostring(value)) end

local gms, get, set = discordia.class("GarrysmodServer", Emitter)

function gms:__init( directory )
	self._dir = directory
	self._playerMax = 32
	
	Emitter.__init(self)
	
	self:on("exit", function()
		self._gamemode = nil
		self._stdin, self._stdout, self._stderr = self._stdin and self._stdin:read_stop() and nil, self._stdout and self._stdout:read_stop() and nil, self._stderr and self._stderr:read_stop() and nil
		self._outbuff, self._errbuff, self._linebuff = nil, nil, nil
		self._proc, self._procId = nil, nil
		self._playerCount = 0
	end)
	
	--[[Accepting P2P request from p2p:76561198116417548.
Client "Men" connected (p2p:76561198116417548).
Dropped Men from server (Disconnect by user.)]]
	
	self:on("consoleOutput", function(line)
		local event = line:match("^%s*Client%s\"(.+)\"%sconnected%s%b()%s*$")
		if event then self._playerCount = math.min(self._playerMax, self._playerCount + 1) self:emit("playerJoined", joined) return end
		event = line:match("^%s*Dropped%s(.+)%sfrom%sserver%s%b()%s*$")
		if event then self._playerCount = math.max(0, self._playerCount - 1) self:emit("playerLeft", joined) return end
	end)
end

function get.running( self )
	return not not (self._proc or self._procId)
end

function get.gamemode( self )
	return self._gamemode
end

function get.map( self )
	return self._map
end

function get.playerCount( self )
	return self._playerCount or 0 
end

function get.playerMax( self )
	return self._playerMax or 0
end

function gms:setToken( token )
	self._gslt = token
end

function gms.cleanProcesses()
	local thread = coroutine.running()
	uv.spawn("taskkill", {stdio = {}, args = {"/f", "/im", "srcds.exe"}}, function() assert(coroutine.resume(thread)) end)
	coroutine.yield()
end

function gms:start( gm, map )
	gm = gm:lower()
	
	-- get gamemode --
	self._gamemode = nil
	for _,v in ipairs(gamemodes) do
		if string.match(gm, v.pattern) then
			self._gamemode = v
			break
		end
	end
	if not self._gamemode then return nil, "invalid gamemode" end
	
	self._map = map or self._gamemode.default_map or "gm_construct"
	
	-- create args --
	local args = {"-console", "+gamemode", self._gamemode.gamemode, "+map", self._map}
	if self._gamemode.collection then insertArg(args, "+host_workshop_collection", self._gamemode.collection) end
	if self._playerMax then insertArg(args, "+maxplayers", self._playerMax) end
	if self._gslt then insertArg(args, "+sv_setsteamaccount", self._gslt) end
	table.insert(args, "-p2p")
	
	-- kill existing srcds processes --
	gms.cleanProcesses()
	
	-- spawn process --
	self._stdin, self._stdout, self._stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
	self._proc = uv.spawn(uv.cwd() .. "\\bin\\srcdspipe.exe", {stdio = {self._stdin, self._stdout, self._stderr}, cwd = self._dir, args = args, detached = true}, function( ... )
		self:emit("exit", ...)
	end)
	
	appdata.writeFileSync( "gm.session", string.pack("LLLLLLL", 
		self._proc:get_pid(), 
		self._stdin:fileno(), self._stdout:fileno(), self._stderr:fileno(),
		0, 0, 0)
	)
	
	self._outbuff, self._errbuff, self._linebuff = {}, {}, {}
	
	local function emitOutput(err, chunk)
		if not chunk then return end
		for line in chunk:gmatch("[^\r\n]+") do
			self:emit("consoleOutput", line)
		end
	end
	
	self._stdout:read_start(function(err, chunk)
		assert(not err, err)
		if not chunk then return end
		table.insert(self._outbuff, chunk)
		emitOutput(err, chunk)
		local joinStr = table.concat(self._outbuff):match("%-%sSteam%sP2P%s%-.-`(.-)`")
		if not joinStr then return end
		appdata.appendFileSync( "gm.session", string.pack("s1", joinStr) )
		self._stdout:read_stop()
		self._stdout:read_start(function(err, chunk)
			emitOutput(err, chunk)
		end)
		self:emit("ready", self._gamemode, joinStr)
	end)
	
	self._stderr:read_start(function(err, chunk)
		assert(not err, err)
		if not chunk then return end
		table.insert(self._errbuff, chunk)
	end)
end

function gms:kill()
	
end

return gms