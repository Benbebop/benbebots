-- sends the bots name to output for multi-bot scripts

local fs = require('fs')

local date = os.date
local format = string.format
local stdout = _G.process.stdout.handle
local openSync, writeSync = fs.openSync, fs.writeSync

-- local BLACK   = 30
local RED     = 33
local GREEN   = 32
local YELLOW  = 33
-- local BLUE    = 34
-- local MAGENTA = 35
local CYAN    = 36
-- local WHITE   = 37

local config = {
        {'[ERR]', RED},
        {'[WRN]', YELLOW},
        {'[INF]', GREEN},
        {'[DBG]', CYAN},
}

do -- parse config
        local bold = 1
        for _, v in ipairs(config) do
                v[3] = format('\27[%i;%im%s\27[0m', bold, v[2], v[1])
        end
end

local discordia = require("discordia")

local Logger = discordia.class.classes.Logger

function Logger:setPrefix(name)
	self._prefix = string.format("%s | ", name)
end

function Logger:log(level, msg, ...)

        if self._level < level then return end

        local tag = config[level]
        if not tag then return end

        msg = format(msg, ...)

        local d = date(self._dateTime)
        if self._file then
                writeSync(self._file, -1, format('%s | %s | %s %s\n', d, tag[1], self._prefix, msg))
        end
        stdout:write(format('%s | %s | %s %s\n', d, tag[3], self._prefix, msg))

        return msg

end
