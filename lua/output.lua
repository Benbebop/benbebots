local str_ext = require("./string")

local truncate = str_ext.truncate

local discordia, appdata, tokens = require('discordia'), require("./appdata"), require("./token")

local outputModes = {null = 16777215, info = 255, err = 16711680, mod = 16737280, warn = 16776960}

local max_output_len, max_foot_len = 4048, 2048

local o = {}
o.__index = o

function create( client )

	return setmetatable({c = client}, o)
	
end

function o:o( str, mode, overwrite_trace )
	if not str then return end
	print( str )
	if mode == "silent" then return end
	str = truncate(str, "desc", true)
	mode = mode or "null"
	local foot = nil
	if mode == "err" then foot = {text = debug.traceback()} end
	if overwrite_trace then foot = {text = overwrite_trace} end
	foot = truncate(foot, "text", true)
	str = str:gsub("%d+%.%d+%.%d+%.%d+", "\\*\\*\\*.\\*\\*\\*.\\*\\*\\*.\\*\\*")
	self.c:getChannel("959468256664621106"):send({
		embed = {
			description = str,
			color = outputModes[mode] or outputModes.null,
			footer = foot,
			timestamp = discordia.Date():toISO('T', 'Z')
		}
	})
end

return create