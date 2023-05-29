local timer = require("timer")

local Stats = {}

local function get(self)
	local client = rawget(self, "client")
	local obj = rawget(self, "obj")
	if not obj then rawset(self, "obj", client:getChannel(rawget(self, "id"))) obj = rawget(self, "obj") end
	return client, obj
end

local function key(vc, index)
	local key, value = vc:match("^(.-)%s*:%s*(.-)$")
	if key ~= index then return nil end
	return tonumber(value) or value
end

function Stats:__index(index)
	local client, channel = get(self)
	
	local value
	for c in channel.voiceChannels:iter() do
		value = key(c.name, index)
		if value ~= nil then
			break
		end
	end
	
	return value
end

function Stats:__newindex(index, value)
	local client, channel = get(self)
	
	local chan
	for c in channel.voiceChannels:iter() do
		local value = key(c.name, index)
		if value ~= nil then
			chan = c
			break
		end
	end
	
	if chan then
		chan._name = index .. " : " .. tostring(value)
		chan:setName(chan.name)
	else
		channel:createVoiceChannel(index .. " : " .. tostring(value))
	end
end

return function(client, id)
	
	return setmetatable({client = client, id = id}, Stats)
	
end