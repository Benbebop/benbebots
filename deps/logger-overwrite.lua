-- sends the bots name to output for multi-bot scripts

local discordia = require("discordia")
local stdout = _G.process.stdout.handle

local Logger = discordia.class.classes.Logger

function Logger:setPrefix(name)
	self._prefix = string.format("%s | ", name)
end

local oldLog = Logger.log

function Logger:log(...)
	if self._prefix then
		stdout:write(self._prefix)
	end

	return oldLog(self, ...)
end
