local uv, timer, fs, assertResume, watcher, readline, appdata = require("uv"), require("timer"), require("fs"), require('utils').assertResume, require("fs-watcher"), require("readline"), require("./appdata")

local ds = {}
ds.__index = ds

function ds.create( directory )

	local pid = appdata.read("gmodprocess")

	local callbacks = {}

	for i=-2,20 do
		callbacks[i] = {}
	end

	return setmetatable({
		dir = directory .. "garrysmod/", 
		directory = directory,
		process = pid, 
		running = pid and true or false,
		p2pid = pid and "PIPEDISCONNECTED" or false,
		args = {"-p2p", "+sv_location", "ca", "+maxplayers", "20", "-console", "+gamemode", "sandbox", "+map", "gm_construct", "+host_workshop_collection", "2855002019"},
		callbacks = callbacks
	}, ds)
	
end

function ds.setGamemode( self, gamemode ) self.args[8] = tostring(gamemode) end
function ds.getArgGamemode( self ) return self.args[8] end

function ds.setMap( self, map ) self.args[10] = tostring(map) end
function ds.getArgMap( self ) return self.args[10] end

function ds.setMaxPlayers( self, count ) self.args[5] = tonumber(count) end
function ds.getArgMaxPlayers( self ) return self.args[5] end

function ds.setCollection( self, id ) self.args[12] = tostring(id) end
function ds.getCollection( self ) return self.args[12] end

--function ds.setAuth( self, key ) self.args[12] = tostring(key) end
function ds.setLocation( self, location ) self.args[2] = tostring(location) end

function ds.getP2PAddress( self ) return self.p2pAddress end

local binary = "I4I4I4I4I4"

appdata.init({{"garrysmod.db", string.pack(binary, 0, 0, 0, 0, 0)}})

function ds.open(self, file, mode)
	return io.open(self.directory .. file, mode)
end

function ds.kill( self )

	if self.process then
		fs.unlinkSync(self.dir .. "data/pipe_outgoing.dat")
		fs.unlinkSync(self.dir .. "data/pipe_incoming.dat")
		appdata.remove("gmodprocess")
		uv.kill(self.process)
		self.process = nil
		self.p2pAddress = nil
		if self.running then
			for _,v in ipairs(self.callbacks[-2] or {}) do
				v("")
			end
		end
		self.running = false
	end
	
end

local function readUntil( file, char )
	local str = ""
	repeat
		local s = file:read(1)
		if s == char then break end
		str = str .. s
	until not s
	return str
end

local NUL = string.char(0)

function ds.newServer( self )

	ds.kill( self )
	
	fs.unlinkSync(self.dir .. "data/pipe_outgoing.dat")
	
	_, self.process = uv.spawn(self.directory .. "srcds.exe", {stdio = {uv.new_tty(1, false), uv.new_tty(0, true)}, args = self.args, detached = true}, function()
		ds.kill( self )
	end)
	
	appdata.write("gmodprocess", tostring(self.process))
	
	watcher.watch(self.dir .. "data/", false, function(event, file)
		if event == 'update' and file == self.dir .. "data/pipe_outgoing.dat" then
			local pipe = io.open(self.dir .. "data/pipe_outgoing.dat", "rb")
			repeat
				local l = pipe:read(1)
				if not l then break end
				local command = pipe:read(string.unpack("B", l))
				for _,v in ipairs(self.callbacks[string.unpack("B", command)] or {}) do
					v(command:sub(2, -1))
				end
			until command == ""
			pipe:close()
			io.open(self.dir .. "data/pipe_outgoing.dat", "wb"):close()
		elseif event == 'error' then
			for _,v in ipairs(self.callbacks[-1] or {}) do
				v(string.pack("z", file))
			end
		end
	end)
	
end

function ds.waitForServer( self, timeout )
	
	local c, t = coroutine.running(), timer.setInterval(500, function()
		
		local content = process.stdin:read()
		
		local id
		
		if content then
			id = content:match("%s*`connect%sp2p:(%d+)`")
		end
		
		if id then
			self.p2pid = id
			assertResume(c, true, id)
		end
		
	end)
	timer.setTimeout(timeout, function()
		timer.clearInterval(t)
		assertResume(c, false, "P2PIDUNKNOWN")
	end)
	
	return coroutine.yield()
	
end

local recieveIndex = {
	[6] = "", [7] = "H", [8] = "s1s1", [9] = "s1", [10] = "s1", [11] = "s1", [12] = "s1",
	shutdown = {-2, ""},
	error = {-1, "z"},
	init = {1, "BBBBH"},
	playerJoined = {2, "s1s1s1"}, -- playerName, playerID
	playerLeft = {5, "s1s1s1"}, -- playerName, playerID, reason
	playerKilled = {3, "s1s1s1"}, -- victimName, weaponName, attackerName
	mapChanged = {4, "s1s1"}, -- mapFrom, mapTo
	connectAccount = {13, "s1s1H"}, -- playerID, discordName, discordDescriminator
}

local sendIndex = {
	accountFound = {1, "B"},
}

--[[ player database spesifications 

ULong - global deaths
ULong - global kills
ULong - global taunts
ULong - global props destroyed
UShort - total rounds
UShort - unused
FOR EACH {
	Byte - length of steamID
	String - steamID
	UShort - deaths
	UShort - kills
	UShort - taunts
	UShort - props destroyed
	UShort - rounds won
	UShort - rounds lost
}

]]

function ds.on( self, event, callback )
	
	local i, p
	
	if type(event) == "number" then
		i, p = event, recieveIndex[event]
	else
		event = recieveIndex[event]
		i, p = event[1], event[2]
	end
	
	table.insert(self.callbacks[i], function(data)
		coroutine.resume( coroutine.create( callback ), string.unpack(p, data) )
	end)
	
end

function ds.send( self, event, ... )
	
	local i, p
	
	if type(event) == "number" then
		i, p = event, recieveIndex[event]
	else
		event = recieveIndex[event]
		i, p = event[1], event[2]
	end
	
	local str = string.pack("B" .. p, i, ...)
	
	local file = io.open(self.dir .. "data/pipe_incoming.dat", "ab")
	file:write(string.pack("s1", str))
	file:close()
	
end

-- DATABASE --

function ds.getStats( self, id )
	
	local database = appdata.get("garrysmod.db", "rb")
	
	if not id then
		
		local deaths, kills, taunts, props, rWon, rLost = string.unpack("LLLLHH", database:read(20))
		
		database:close()
		
		return {deaths = deaths, kills = kills, taunts = taunts, props = props, rWon = rWon, rLost = rLost}
		
	end
	
	repeat
		local l = database:read(1)
		if not l then break end
		local dbid = database:read(string.unpack("B", l))
		if dbid == id then
			found = true
			local deaths, kills, taunts, props, rWon, rLost = string.unpack("HHHHHH", database:read(12))
			return {deaths = deaths, kills = kills, taunts = taunts, props = props, rWon = rWon, rLost = rLost}
		else
			database:seek("cur", 12)
		end
	until not l
	
	return nil
	
end

function ds.addDeath( self, id )
	
	local database = appdata.get("garrysmod.db", "r+")
	
	database:seek("set")
	
	local deaths = string.unpack("L", database:read(4))
	database:seek("set")
	database:write(string.pack("L", deaths + 1))
	database:seek("cur", 16)
	
	local found = false
	
	repeat
		local l = database:read(1)
		if not l then break end
		local dbid = database:read(string.unpack("B", l))
		if dbid == id then
			found = true
			deaths = string.unpack("H", database:read(2))
			database:seek("cur", -2)
			database:write(string.pack("H", deaths + 1))
			break
		else
			database:seek("cur", 12)
		end
	until not l
	
	if not found then
		
		database:write(string.pack("s1HHHHHH", id, 1, 0, 0, 0, 0, 0 ))
		
	end
	
	database:close()
	
end

function ds.addFrag( self, id )
	
	local database = appdata.get("garrysmod.db", "r+")
	
	database:seek("set", 4)
	
	local frags = string.unpack("L", database:read(4))
	database:seek("set", 4)
	database:write(string.pack("L", frags + 1))
	database:seek("cur", 12)
	
	local found = false
	
	repeat
		local l = database:read(1)
		if not l then break end
		local dbid = database:read(string.unpack("B", l))
		if dbid == id then
			found = true
			database:seek("cur", 2)
			frags = string.unpack("H", database:read(2))
			database:seek("cur", -2)
			database:write(string.pack("H", frags + 1))
			break
		else
			database:seek("cur", 12)
		end
	until not l
	
	if not found then
		
		database:write(string.pack("s1HHHHHH", id, 0, 1, 0, 0, 0, 0 ))
		
	end
	
	database:close()
	
end

function ds.addTaunt( self, id )
	
	local database = appdata.get("garrysmod.db", "r+")
	
	database:seek("set", 8)
	
	local taunts = string.unpack("L", database:read(4))
	database:seek("set", 8)
	database:write(string.pack("L", taunts + 1))
	database:seek("cur", 8)
	
	local found = false
	
	repeat
		local l = database:read(1)
		if not l then break end
		local dbid = database:read(string.unpack("B", l))
		if dbid == id then
			found = true
			database:seek("cur", 4)
			taunts = string.unpack("H", database:read(2))
			database:seek("cur", -2)
			database:write(string.pack("H", taunts + 1))
			break
		else
			database:seek("cur", 12)
		end
	until not l
	
	if not found then
		
		database:write(string.pack("s1HHHHHH", id, 0, 0, 1, 0, 0, 0 ))
		
	end
	
	database:close()
	
end

function ds.addProp( self, id )
	
	local database = appdata.get("garrysmod.db", "r+")
	
	database:seek("set", 12)
	
	local taunts = string.unpack("L", database:read(4))
	database:seek("set", 12)
	database:write(string.pack("L", taunts + 1))
	database:seek("cur", 4)
	
	local found = false
	
	repeat
		local l = database:read(1)
		if not l then break end
		local dbid = database:read(string.unpack("B", l))
		if dbid == id then
			found = true
			database:seek("cur", 6)
			taunts = string.unpack("H", database:read(2))
			database:seek("cur", -2)
			database:write(string.pack("H", taunts + 1))
			break
		else
			database:seek("cur", 12)
		end
	until not l
	
	if not found then
		
		database:write(string.pack("s1HHHHHH", id, 0, 0, 0, 1, 0, 0 ))
		
	end
	
	database:close()
	
end

function ds.addConnectedAccount( self, discordID, steamID )
	
	local database = appdata.get("connectedAccounts.db", "r+")
	
	local found = false
	
	repeat
		local l = database:read(1)
		if not l then break end
		local dID, sID = string.unpack("zz", database:read(string.unpack("B", l)))
		if dID == discordID or sID == steamID then
			found = true
			break
		end
	until not l
	
	if not found then
		database:write(string.pack("s1", string.pack("zz", discordID, steamID)))
	end
	
	database:close()
	
end

function ds.getConnectedAccount( self, steamID )
	
	local database = appdata.get("connectedAccounts.db", "r+")
	
	local id = false
	
	repeat
		local l = database:read(1)
		if not l then break end
		local dID, sID = string.unpack("zz", database:read(string.unpack("B", l)))
		if sID == steamID then
			id = dID
			break
		end
	until not l
	
	database:close()
	
	return id
	
end

-- MODS --

local function fakeParseKeyValue( file, maxLength ) -- use until proper key value parser
	repeat
		local s = file:read("*l")
		if not s then break end
		local key, token = s:match("\"(.-[^\\])\"%s*\"(.-[^\\])\"")
		if key == "maps" and token then
			return token
		end
	until maxLength and (file:seek("cur") > maxLength)
	return ""
end

function ds.listGamemodes( self )
	local tbl = {}
	for name,t in fs.scandirSync(self.dir .. "addons") do
		if t == "file" and name:sub(-4) == ".gma" then
			local file = io.open(self.dir .. "addons/" .. name, "rb")
			file:seek("set", 22) readUntil( file, NUL ) readUntil( file, NUL ) readUntil( file, NUL ) file:seek("cur", 5)
			repeat
				local fileNum = string.unpack("I4", file:read(4))
				if (fileNum or 0) == 0 then
					break
				end
				local gamemode, fileCheck = readUntil( file, NUL ):match("^gamemodes/([^/]+)/([^%.]+)%.txt$")
				if gamemode == fileCheck then
					table.insert(tbl, gamemode)
				end
				file:seek("cur", 12)
			until (fileNum or 0) == 0
			file:close()
		elseif t == "directory" and fs.existsSync(self.dir .. "addons/" .. name .. "/gamemodes") then
			for name,t in fs.scandirSync(self.dir .. "addons/" .. name .. "/gamemodes") do
				if t == "directory" then
					table.insert(tbl, name)
				end
			end
		end
	end
	for name,t in fs.scandirSync(self.dir .. "gamemodes") do
		if t == "directory" and name ~= "base" then
			table.insert(tbl, name)
		end
	end
	return tbl
end

function ds.listMaps( self )
	local tbl = {}
	for name,t in fs.scandirSync(self.dir .. "addons") do
		if t == "file" and name:sub(-4) == ".gma" then
			local file = io.open(self.dir .. "addons/" .. name, "rb")
			file:seek("set", 22) readUntil( file, NUL ) readUntil( file, NUL ) readUntil( file, NUL ) file:seek("cur", 5)
			repeat
				local fileNum = string.unpack("I4", file:read(4))
				if (fileNum or 0) == 0 then
					break
				end
				local map = readUntil( file, NUL ):match("^maps/([^%./]+)%.bsp$")
				if map then
					table.insert(tbl, {name = map, dir = self.dir .. "addons/"})
				end
				file:seek("cur", 12)
			until (fileNum or 0) == 0
			file:close()
		elseif t == "directory" and fs.existsSync(self.dir .. "addons/" .. name .. "/maps") then
			for n,t in fs.scandirSync(self.dir .. "addons/" .. name .. "/maps") do
				if t == "file" and n:sub(-4) == ".bsp" then
					table.insert(tbl, {name = n:sub(1, -5), dir = self.dir .. "addons/" .. name .. "/maps/"})
				end
			end
		end
	end
	for name,t in fs.scandirSync(self.dir .. "maps") do
		if t == "file" and name:sub(-4) == ".bsp" then
			table.insert(tbl, {name = name:sub(1, -5), dir = self.dir .. "maps/"})
		end
	end
	return tbl
end

function ds.listMapsByGamemode( self, gm )
	local maps, prefixes, other = {}, nil, gm == "other"
	if gm == "base" then return false end
	for name,t in fs.scandirSync(self.dir .. "addons") do
		if t == "file" and name:sub(-4) == ".gma" then
			local file = io.open(self.dir .. "addons/" .. name, "rb")
			file:seek("set", 22) readUntil( file, NUL ) readUntil( file, NUL ) readUntil( file, NUL ) file:seek("cur", 5)
			repeat
				local fileNum = string.unpack("I4", file:read(4))
				if (fileNum or 0) == 0 then
					break
				end
				local fileName = readUntil( file, NUL )
				local map = fileName:match("^maps/([^%./]+)%.bsp$")
				local gamemode, fileCheck = fileName:match("^gamemodes/([^/]+)/([^%.]+)%.txt$")
				if (gamemode == fileCheck and gamemode == gm) or other then
					prefixes = {} --TODO prefix code
				elseif map then
					table.insert(maps, {name = map, dir = self.dir .. "addons/"})
				end
				file:seek("cur", 12)
			until (fileNum or 0) == 0
			file:close()
		elseif t == "directory" and fs.existsSync(self.dir .. "addons/" .. name .. "/maps") then
			for map,t in fs.scandirSync(self.dir .. "addons/" .. name .. "/maps") do
				if t == "file" and map:sub(-4) == ".bsp" then
					table.insert(maps, {name = map:sub(1, -5), dir = self.dir .. "addons/" .. name .. "/maps/"}) 
				end
			end
			if (not prefixes) or other and fs.existsSync(self.dir .. "addons/" .. name .. "/gamemodes") then
				for gamemode,t in fs.scandirSync(self.dir .. "addons/" .. name .. "/gamemodes") do
					if t == "directory" and gamemode == gamemode then
						local file = io.open(self.dir .. "addons/" .. name .. "/gamemodes/" .. gamemode .. "/" .. gamemode .. ".txt", "rb")
						prefixes = {}
						for m in fakeParseKeyValue(file):gmatch("[^|]+") do
							table.insert(prefixes, m)
						end
						break
					end
				end
			end
		end
	end
	for name,t in fs.scandirSync(self.dir .. "maps") do
		if t == "file" and name:sub(-4) == ".bsp" then
			table.insert(maps, {name = name:sub(1, -5), dir = self.dir .. "maps/"})
		end
	end
	if (not prefixes) or other then
		for gamemode,t in fs.scandirSync(self.dir .. "gamemodes") do
			if t == "directory" and gamemode == gm then
				local file = io.open(self.dir .. "gamemodes/" .. gamemode .. "/" .. gamemode .. ".txt", "rb")
				prefixes = {}
				for m in fakeParseKeyValue(file):gmatch("[^|]+") do
					table.insert(prefixes, m)
				end
			end
		end
	end
	if not prefixes then return false end
	local tbl = {}
	for _,v in ipairs(maps) do
		for _,k in ipairs(prefixes) do
			local match = not not v:match(k)
			if (not other) and match then
				table.insert(tbl, v)
			elseif other and (not match) then
				table.insert(tbl, v)
			end
		end
	end
	return tbl
end

local function readUntil(file, char)
	local str, next = "", ""
	repeat
		str = str .. next
		next = file:read(1)
	until next == char
	return str
end

local NUL = string.char(0)

function ds.getVBSPContent( file )
	file = io.open(file, "r+")
	if file:read(4) ~= "VBSP" then return false, "file not valve bsp" end
	local version = string.unpack("I4", file:read(4))
	file:seek("cur", 16 * 43)
	local texOffset, texLength = string.unpack("I4I4", file:read(16))
	file:seek("set", texOffset)
	local tbl = {}
	repeat
		table.insert(tbl, readUntil(file, NUL):lower())
	until file:seek("cur") >= texOffset + texLength
	return tbl
end

function ds.getVBSPPacked()
	file:seek("cur", 16 * 40)
	local pakOffset, pakLength = string.unpack("I4I4", file:read(16))
end

function ds.compareAsset(file, compare)
	local found = false
	file:seek("set", 4)
	local pos, max = 0, math.huge
	for v in compare:gmatch("[^\\/]+") do
		repeat
			if file:seek("cur") >= max then return false end
		until v == readUntil(file, NUL)
	end
	return found
end

-- NON-SERVER RELATED --

function ds.parseKeyValue( file )
	
end

function ds.getSteamIDByName( player )
	
end

ds.gameColor = "1152240"

return ds