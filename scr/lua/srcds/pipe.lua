local uv, fs, json = require("uv"), require("fs"), require("json")

local singalIndex = json.parse(fs.readFileSync("lua/srcds/signals.json"))
local responseSignal
for i,v in ipairs( singalIndex.host ) do if v[1] == "RESPONSE" then responseSignal = i break end end

local pipe = {}
pipe.__index = pipe

function pipe.__gc( self )
	
end
pipe.close = pipe.__gc

-- SEND SIGNAL --

function pipe.sendSignal( self, signal, callback, ... )
	local ident, signalNum = #returnCallbacks + 1
	for i,v in ipairs(signalIndex.host) do
		if v[1] == signal then signalNum, signal = i, v break end
	end
	self.returnCallbacks[ident] = callback
	local output = fs.openSync( self.dir .. "pipe_0.dat", "a" )
	fs.writeSync( output, string.pack( "HBs2", signalNum, ident, string.pack(v[2]) ) )
	fs.closeSync( output )
end

function pipe.sendSignalSync( self, signal, ... )
	
	local thread = coroutine.running()
	
	pipe.sendSignal( self, signal, function( ... )
		coroutine.resume( thread, ... )
	end, ... )
	
	return coroutine.yield()
	
end

-- RECIEVE SIGNAL --

local function activateSignalEvent( self )
	
	if not self.signalEventActive then
		
		self.signalEvent:start( self.dir, {}, function( err, filename, events )
			if filename == "pipe_1.dat" and events.changed then
				local input, output = fs.openSync( self.dir .. "pipe_1.dat", "r" ), fs.openSync( self.dir .. "pipe_0.dat", "a" )
				
				local sData = fs.readSync( input, 0, 5 )
				local cursor = 5
				while sData do
					local signal, ident, len = string.unpack("HBH", sData)
					local content = fs.readSync( input, cursor, len )
					cursor = cursor + len
					
					local signalInfo = signalIndex.server[signal] -- get signal info
					
					if signalInfo[1] == "RESPONSE" then -- if signal is response
						local signalReturns = {string.unpack(signalInfo[3], content)} -- unpack signal params
						if self.returnCallbacks[ident] then self.returnCallbacks[ident](unpack(signalReturns)) end
						table.remove(self.returnCallbacks, ident)
					else -- if signal is incomming
						local signalParams = {string.unpack(signalInfo[2], content)} -- unpack signal params
						for i,v in ipairs(self.signalCallbacks[signal]) do
							local results = {v.run(unpack(signalParams))}
							if v.once then -- if callback is once only
								table.remove( self.signalCallbacks, i )
							end
							local signalReturns = string.pack( signalInfo[3], unpack(results) ) -- repack results of function
							fs.writeSync( output, string.pack("HBs2", responseSignal, ident, signalReturns) )
						end
					end
					
					sData = fs.readSync( input, cursor, 5 )
					cursor = cursor + 5
				end
				
				fs.closeSync( input ) fs.closeSync( output )
			end
		end)
		self.signalEventActive = true
		
	end
	
end

local function deactivateSignalEvent( self )
	
	if self.signalEventActive then
		
		self.signalEvent:stop()
		self.signalEventActive = false
		
	end
	
end

-- RECIEVE SIGNAL FUNCTIONS --

function pipe.onSignal( self, signal, callback )
	activateSignalEvent( self )
	if not self.signalCallbacks[signal] then self.signalCallbacks[signal] = {} end
	table.insert( self.signalCallbacks[signal], {run = callback} )
	return callback
end

function pipe.offSignal( self, signal, callback )
	deactivateSignalEvent( self )
	for i,v in ipairs(self.signalCallbacks[signal] or {}) do
		if v == callback then table.remove( self.signalCallbacks[signal], i ) end
	end
end

function pipe.onceSignal( self, signal, callback )
	activateSignalEvent( self )
	if not self.signalCallbacks[signal] then self.signalCallbacks[signal] = {} end
	table.insert( self.signalCallbacks[signal], {once = true, run = callback} )
end

return function( dir )
	
	local self = {
		signalCallbacks = {}, returnCallbacks = {},
		signalEvent = uv.new_fs_event(), signalEventActive = false,
		dir = dir
	}
	
	return setmetatable( self, pipe )
	
end