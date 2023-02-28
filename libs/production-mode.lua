-- blocks all events from the testing channel

local discordia = require("discordia")

local Client = discordia.class.classes.Client

local oldEmit = Client.emit

local testChannel = "1068657073321169067"

function Client:emit(name, ...)
	if not self._listeners[name] then return end -- quick way out
	local args = {...}
	
	local cancel = false
	
	for _,v in ipairs(args) do
		if type(v) == "table" and ((v.id == testChannel) or
			(v._parent and v._parent.id == testChannel) or 
			(v._channel and v._channel.id == testChannel)) then cancel = true break
		elseif v == testChannel then cancel = true break end
	end
	
	if cancel then self:warning("Ignoring event from test channel") return end
	
	return oldEmit(self, name, ...)
end

return Client