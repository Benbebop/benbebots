-- hello everybody my name is multiplayer!
local parseUrl, thread = require("url").parse, require("thread")

_G.multiplayerThreads = {}

-- custom stream object for connection:_play() --

local FFmpegProcess = require("discordia").class.classes.FFmpegProcess

local ytdlpStream = {}
ytdlpStream.__index = ytdlpStream

local function onExit() end

function ytdlpStream.__init(self, url, rate, channels)
	
	local stdout, stdin = uv.new_pipe(false), uv.new_pipe(false)

	self._child = assert(uv.spawn('bin/ffmpeg', {
		args = {'-i', "-", '-ar', rate, '-ac', channels, '-f', 's16le', 'pipe:1', '-loglevel', 'warning'},
		stdio = {stdin, stdout, 2},
	}, onExit), 'ffmpeg could not be started, is it installed and on your executable path?')
	assert(uv.spawn('bin/yt-dlp', {
		args = {"-o", "-", "-f", "ba*/b", url},
		stdio = {0, stdin, 2},
	}, onExit), 'ytdlp could not be started, is it installed and on your executable path?')

	local buffer
	local thread = coroutine.running()
	stdout:read_start(function(err, chunk)
		if err or not chunk then
			self:close()
		else
			buffer = chunk
		end
		stdout:read_stop()
		return assert(coroutine.resume(thread))
	end)

	self._buffer = buffer or ''
	self._stdout = stdout

	coroutine.yield()
	
end

ytdlpStream.__tostring = FFmpegProcess.__tostring
ytdlpStream.read = FFmpegProcess.read
ytdlpStream.close = FFmpegProcess.close

-- main --

local playerThread = {}
playerThread.__index = playerThread
playerThread.__newindex = {}

function playerThread.new( self, channel )
	channel = channel or self
	
	local index = channel.guild.id
	
	if multiplayerThreads[index] then return multiplayerThreads[index] end
	
	local connection = channel.guild._connection or channel:join()
	
	if not connection then return nil end
	
	multiplayerThreads[index] = setmetatable({
		index = index, connection = connection,
		queue = {n = 0}, workThread = nil
	}, playerThread)
	
	return multiplayerThreads[index]
	
end

function playerThread.close( self )
	
end

function playerThread._workQueue( self )
	
	if rawget(self, "workThread") then return nil end
	
	local workThread = coroutine.create(function( self )
		local queue, connection = rawget(self, "queue"), rawget(self, "connection")
		repeat
			
			local toPlay = queue[1]
			table.remove(queue, 1)
			queue.n = queue.n - 1
			
			local poopy = setmetatable({}, ytdlpStream):__init(table.concat({"https://", toPlay[1], toPlay[2], "?", toPlay[3]}), 48000, 2)
			
			p(poopy)
			
			thread.join(assert(thread.start(function( connection, stream )
				p("krill your shelf")
				connection:_play( stream )
			end, connection, poopy)))
			
		until queue.n <= 0
		playerThread.close( self )
	end)
	
	rawset(self, "workThread",  workThread)
	
	coroutine.resume(workThread, self)
	
end

function playerThread.skip( self )
	
end

function playerThread.getQueue( self )
	
end

function playerThread.remove( self, index )
	
	table.remove(rawget(self, "queue"), index)
	queue.n = queue.n - 1
	
end

function playerThread.add( self, url )
	url = parseUrl(url)
	
	if not url.host then return false, "invalid url" end
	
	local queue = rawget(self, "queue")
	
	local index = queue.n + 1
	
	queue[index] = {url.hostname, url.pathname, url.query}
	queue.n = queue.n + 1
	
	playerThread._workQueue( self )
	
	return index
end

return setmetatable({}, {__index = {new = playerThread.new}})