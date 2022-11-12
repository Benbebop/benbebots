local uv, fs, watcher = require("uv"), require("fs"), require("fs-watcher")

local assertResume = require("utils").assertResume

local srds = {}
srds.__index = srds

-- generate a steam browser protocol link to join the game --
function srds.sbpLink( self )
	
	if not self.p2pId then return nil end
	
	return "steam://run/4000//--connect%20" .. self.p2pId
	
end

-- server pipe --

local pstdin, pstdout = "garrysmod/data/pipe_outgoing.dat", "garrysmod/data/pipe_incoming.dat"

--[[
packet spesification

long[4] = identifier
byte[1] = length of packet
string = command name
byte[1] = zero

]]

local sp = {}
sp.__index = sp

function srds._createServerPacket( self )
	
	if not self.pstdio.out then return nil end
	
	self.identIndex = self.identIndex + 1
	
	return setmetatable( {packets = {""}, ident = self.identIndex, io = self.dir .. pstdin}, sp )
	
end

function sp.newPacket( self )
	
	assert( self.packets )
	
	self.packets[#self.packets + 1] = ""
	
end

function sp.write( self, ... )
	
	assert( self.packets )
	
	local p = self.packets
	
	for _,v in ipairs( ... ) do
		
		if type(v) == "string" then
			self.packets[#p] = p[#p] .. v
		elseif type(v) == "number" then
			self.packets[#p] = p[#p] .. string.char(v)
		end
		
	end
	
end

local pack, upack = string.pack, string.unpack

function sp.send( self )
	
	assert( self.packets )
	
	local pstdio = fs.openSync( self.io, "a" )
	for _,v in ipairs(self.packets) do
		fs.writeSync( pstdio, pack("Ls1", self.ident, v) )
	end
	fs.closeSync( pstdio )
	
	self.packets = nil
	
	return 
	
end

-- called every time a new batch of packets come in --
local function processPackets( file )
	
	local fd = fs.openSync(file, "r")
	local packets = fs.readSync( fd )
	local packetsLength = #packets
	if packetsLength <= 0 then return end
	fs.ftruncateSync(fd, 0)
	fs.closeSync( fd )
	
	local packetTable = {}
	
	local cursor = 0
	repeat
		
		local ident, contentLength = packets:sub(cursor, cursor + 5)
		cursor = cursor + 6
		
		local content = packets:sub(cursor, cursor + contentLength)
		cursor = cursor + contentLength
		
		table.insert(packetTable, {ident, content} )
		
	until cursor >= packetsLength
	
	return packetTable
	
end

-- add callback to be called on every new incoming packet --
function srds._addPacketCallback( self, callback )
	
	if not self.pstdio["in"] then return false end
	
	local id = #self.packetCallbacks + 1
	
	self.packetCallbacks[id] = callback
	
	return id
	
end

-- remove a packet callback --
function srds._removePacketCallback( self, id )
	
	table.remove(self.packetCallbacks, id)
	
end

-- send and recieve commands --
local cSchema = {
	_resp = false, -- (internal)
	ping = {},
	closeserver = {""}
}

-- subscribe to a certain command packet --
function srds.onCommand( self, command, callback )
	local schema = cSchema[command]
	if not schema then return end
	
	if not self.commandCallbacks[command] then self.commandCallbacks[command] = {} end
	table.insert(self.commandCallbacks[command], callback)
end

-- send command packet to server --
function srds.sendCommand( self, command, callback, ... )
	
	local schema = cSchema[command]
	
	local packet = srds._createServerPacket( self )
	if not (schema and packet) then return false end
	packet:write( pack( "z" .. schema[1], command, ... ) )
	local identifier = packet:send()
	
	if schema[2] then
		
		local id = srds._addPacketCallback( self, function( ident, data )
			
			if upack( "z", data ) == "_resp" then
				
				local _, ident, content = upack( "zLz", data )
				
				if ident ~= identifier then return end
				
				callback( upack( schema[2], content ) )
				
				srds._removePacketCallback( self, id )
				
			end
			
		end)
		
	end
	
end

-- sync version of sendCommand --
function srds.sendCommandSync( self, command, timeout, ... )
	
	local thread = coroutine.running()
	
	srds.sendCommand( self, command, function( ... )
		
		assertResume( thread, ... )
		
	end, ... )
	
	return coroutine.yield()
	
end

-- internal, reset between sessions --
function srds._reset( self )
	
	self.p2pId = nil
	if fs.existsSync(self.dir .. pstdin) then fs.unlink(self.dir .. pstdin) end
	if fs.existsSync(self.dir .. pstdout) then fs.unlink(self.dir .. pstdout) end
	self.pstdio = {}
	self.identIndex = 0
	self.packetCallbacks = {}
	self.commandCallbacks = {}
	if self.instance then self.instance:kill() end
	self.instance = nil
	if self.watcherInstance then watcher.stop( self.watcherInstance ) end
	self.watcherInstance = nil
	
end

-- immediately kill server process and reset object --
function srds.kill( self )
	
	assert( self.instance )
	
	self.instance:kill()
	
	srds._reset( self )
	
end

-- kick all players then kill server process and reset object --
function srds.close( self )
	
	assert( self.instance )
	
	assert( srds.sendCommandSync( self, "closeserver", 5 ) )
	
	srds.kill( self )
	
end

-- start server and initialize functions and such --
function srds.start( self,  gamemode )
	
	srds._reset( self )
	
	-- SETUP PSTDIO --
	local pstdout, pstdin = self.dir .. pstdout, self.dir .. pstdin --files are named according to the gmod server, they are the other way around for us
	
	local thread = coroutine.running()
	
	local callback = watcher.watch(self.dir .. "garrysmod/data/", false, function(event, file)
		if event == 'create' then
			if file == pstdin then
				self.pstdio["in"] = true
			elseif file == pstdout then
				self.pstdio.out = true
			end
			if self.pstdio.out and self.pstdio["in"] then
				assertResume(thread)
			end
		end
	end)
	
	-- START SERVER INSTANCE --
	self.instance = uv.spawn( self.dir .. "srcds.exe", {stdio = {0, 1}, args = {"-p2p", "+sv_location", "ca", "+maxplayers", "128", "-console", "+gamemode", gamemode, "+map", "gm_construct", "+host_workshop_collection", "2855002019"}}, function()
		
		assertResume(thread, true)
		
		srds._reset( self )
		
		coroutine.wrap(benbebase.output)( "sourcededicatedserver: server unexpectedly crashed, shoutout facepunch for not giving a way to get p2p server ids" )
		
	end)
	
	-- WAIT FOR SERVER TO START PSTDIO --
	local err = coroutine.yield()
	
	watcher.stop( callback )
	
	if err then return end
	
	-- START PSTDIO --
	self.watcherInstance = watcher.watch(self.dir .. "garrysmod/data/", false, function(event, file)
		if event == 'update' and file == (self.dir .. pstdin) then
			local packets = processPackets( self.dir .. pstdin )
			if not packets then return end
			for _,packet in ipairs(packets) do
				for _,callback in ipairs(packetCallbacks) do
					callback(unpack(packet))
				end
			end
		end
	end)
	
	-- PSTDIO COMMAND HANDLER --
	srds._addPacketCallback( self, function( ident, data )
		
		local command = upack( "z", data )
		local schema = cSchema[command]
		command = self.commandCallbacks[command]
		
		if command then
			
			for i,v in ipairs(command) do
				
				v(upack(schema, data))
				
			end
			
		end
	end)
	
	return true
	
end

-- there is no words to describe the rage i feel --
function srds.promptUserInputP2pId( self )
	
	io.write("please input the p2p id of the spawned server")
	
	self.p2pId = io.read():match("%d+")
	
end

return function( gameDir )
	
	return setmetatable({
		p2pId = nil,
		pstdio = {},
		identIndex = 0,
		packetCallbacks = {},
		commandCallbacks = {},
		dir = gameDir,
		instance = nil,
		watcherInstance = nil
	}, srds)
	
end