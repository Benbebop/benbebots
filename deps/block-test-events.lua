-- blocks any webhook events coming from the testing channel
local uv = require("uv")

if uv.os_gethostname() ~= "benbebot-server-computer" then return end

local discordia = require("discordia")

local Client = discordia.class.classes.Client

local oldemit = Client.emit

function Client:emit(...)
	local _, obj = ...
	
	if (type(obj) == "table") and (type(obj.channel) == "table") and obj.channel.id == "1068657073321169067" then return end
	
	return oldemit(self, ...)
end