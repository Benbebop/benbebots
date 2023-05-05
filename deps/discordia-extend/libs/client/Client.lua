local discordia = require("discordia")
local class = discordia.class

local Client = class.classes.Client
local Color = discordia.Color()

local colors = {error = Color.fromRGB(197, 15, 31),warning = Color.fromRGB(193, 156, 0),info = Color.fromRGB(22, 198, 12),debug = Color.fromRGB(97, 214, 214)}

function Client:setLogChannel(channelId) self._logChannel = channelId end

function Client:outputNoPrint(mode, ...)
	
	self:getChannel(self._logChannel):send({embed = {
		description = string.format(...),
		color = colors[mode].value
	}})
	
end

function Client:output(mode, ...)
	
	self[mode](self, ...)
	
	self:outputNoPrint(mode, ...)
	
end