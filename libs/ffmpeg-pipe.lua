local uv = require("uv")

local discordia = require("discordia")

local class = discordia.class
local yield, resume, running = coroutine.yield, coroutine.resume, coroutine.running

local FFmpegProcess = class.classes.FFmpegProcess
local FFmpegPipe = class("FFmpegPipe", FFmpegProcess)

function FFmpegPipe:__init(stdin, rate, channels)
	
	local stdout = uv.new_pipe(false)
	
	self._child = assert(uv.spawn('ffmpeg', {
		args = {'-i', "pipe:", '-ar', rate, '-ac', channels, '-f', 's16le', 'pipe:1', '-loglevel', 'warning'},
		stdio = {stdin, stdout, 2},
	}, onExit), 'ffmpeg could not be started, is it installed and on your executable path?')

	local buffer
	local thread = running()
	stdout:read_start(function(err, chunk)
		if err or not chunk then
			self:close()
		else
			buffer = chunk
		end
		stdout:read_stop()
		return assert(resume(thread))
	end)

	self._buffer = buffer or ''
	self._stdout = stdout

	yield()

end

return FFmpegPipe