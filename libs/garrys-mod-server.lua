local uv, fs, json, timer, appdata = require("uv"), require("fs"), require("json"), require("timer"), require("appdata")
local discordia = require("discordia")

local Emitter = discordia.class.classes.Emitter

local gamemodes = json.parse(fs.readFileSync("resource/gamemodes.json"))
assert(gamemodes, "failed to parse gamemode json")

local function insertArg( tbl, arg, value ) table.insert(tbl, tostring(arg)) table.insert(tbl, tostring(value)) end

local gms, get, set = discordia.class("GarrysmodServer", Emitter)

function gms:__init( directory )
	local init = appdata.readFileSync( "gm.session" )
	if init then
		init = {string.unpack("LLLLLLL", init)}
		
		self._procId = init[1]
		
		self._stdin, self._stdout, self._stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
		self._stdin:open(init[2]) self._stdout:open(init[3]) self._stderr:open(init[4])
	end
	
	self._dir = directory
	self._playerMax = 32
	
	Emitter.__init(self)
	
	self:on( "consoleOutput", function( line )
		p(line)
	end )
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

function gms:start( gm, map )
	gm = gm:lower()
	self._waitingForServer = {}
	
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
	
	-- spawn process --
	self._stdin, self._stdout, self._stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
	self._proc = uv.spawn(uv.cwd() .. "\\bin\\srcdspipe.exe", {stdio = {self._stdin, self._stdout, self._stderr}, cwd = self._dir, args = args, detached = true}, function()
		appdata.unlinkSync( "gm.session" )
		
		if self._waitingForServer then
			local err = self._errbuff[1] and table.concat(self._errbuff)
			for _,v in ipairs(self._waitingForServer) do coroutine.resume(v, nil, err or "server closed") end
		else
			self:emit("exit")
		end
	end)
	
	appdata.writeFileSync( "gm.session", string.pack("LLLLLLL", 
		self._proc:get_pid(), 
		self._stdin:fileno(), self._stdout:fileno(), self._stderr:fileno(),
		0, 0, 0)
	)
	
	self._outbuff, self._errbuff, self._linebuff = {}, {}, {}
	
	self._stdout:read_start(function(err, chunk)
		assert(not err, err)
		if not chunk then return end
		table.insert(self._outbuff, chunk)
		local joinStr = table.concat(self._outbuff):match("%-%sSteam%sP2P%s%-.-`(.-)`")
		if not joinStr then return end
		for _,v in ipairs(self._waitingForServer) do coroutine.resume(v, joinStr) end
		self._waitingForServer = nil
		appdata.appendFileSync( "gm.session", string.pack("s1", joinStr) )
		self._stdout:read_stop()
		self._stdout:read_start(function(err, chunk)
			table.insert(self._linebuff, chunk)
			
			for _,v in table.concat(self._linebuff):gmatch("^([^\n]+)%s*$") do
				self._linebuff = {}
				
				self:emit( "consoleOutput", v )
			end
		end)
	end)
	
	self._stderr:read_start(function(err, chunk)
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
	local r = {coroutine.yield()}
	timer.clearTimeout(t)
	return unpack(r)
end

function gms:getConsole()
	return self._outbuff and table.concat(self._outbuff)
end

function gms:kill()
	
end

return gms