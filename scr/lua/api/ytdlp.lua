local uv, fs, timer, appdata = require("uv"), require("fs"), require("timer"), require("../appdata")

local assertResume = require("utils").assertResume

local function assertContinue( self )
	
	self.threading.count = self.threading.count - 1
	
	if self.threading.count < self.threading.max then
		
		assertResume( self.instance )
		
	end
	
end

local ytdlp = {}
ytdlp.__index = ytdlp

local function downloadQueue( self )
	
	repeat
		
		local work = self.q[1]
		
		table.remove(self.q, 1)
		
		local thread = coroutine.create(function()
			
			local results, errors = "", ""
			
			local stdout, stderr = uv.new_pipe(false), uv.new_pipe(false)
			
			local proc = uv.spawn( "bin/yt-dlp.exe", {stdio = {nil, stdout, stderr}, args = work.args}, function() assertContinue( thread ) end )
			
			stdout:read_start( function(err, data)
				if err then
					proc:kill()
					assertContinue( thread )
					coroutine.wrap(work.onFinish)( err )
				elseif data then
					results = results .. data
				end
			end)
			stderr:read_start( function(err, data)
				if err then
					proc:kill()
					assertContinue( thread )
					coroutine.wrap(work.onFinish)( err )
				elseif data then
					errors = errors .. data
				end
			end)
			
			local u = function()
				if #results > 1000 then results = results:sub(-500, -1) end
				local status = results:match("[^\n\r]+%s*$")
				if status then
					coroutine.wrap(work.progress)( status )
				end
			end
			
			local update = timer.setInterval(2500, u)
			u()
			
			coroutine.yield()
			
			local file = results:match("([^\"]+)\"%s*$")
			
			timer.clearInterval( update )
			
			if errors ~= "" then
				work.onFinish( errors )
			elseif not file then
				work.onFinish( "somethin broke idk" )
			else
				work.onFinish( false, file )
			end
				
			fs.unlink( file )
			
			assertContinue( self )
			
		end)
		
		coroutine.resume( thread )
		
		self.threading.count = self.threading.count + 1
		
		benbebase.debugVars.ytdlp_threads = self.threading.count
		
		if self.threading.count >= self.threading.max then coroutine.yield() end
		
	until #self.q <= 0
	
	self.instance = nil
	
end

function ytdlp.queue( self, options, progress, onFinish )
	
	table.insert( options, 1, "-o" ) table.insert( options, 2, appdata.tempDirectory() .. "%(id)s_%(extractor_key)s.%(ext)s" )
	
	local simSuccess, simResults = true, ""
	
	--check if valid video
	do
		local thread = coroutine.running()
		
		local simOptions = {table.unpack(options)}
		table.insert( simOptions, 3, "-s" )
		
		local stderr = uv.new_pipe()
		
		local proc = uv.spawn( "bin/yt-dlp.exe", {stdio = {nil, nil, stderr}, args = simOptions}, function() assertResume( thread ) end )
		
		stderr:read_start( function(err, data)
			
			if err then
				
				simSuccess, simResults = false, "internalerror:ERRPIPE(" .. err .. ")"
				proc:kill()
				assertResume( thread )
				
			elseif data then
				
				simResults = simResults .. data
				
			end
			
		end)
		
		coroutine.yield()
		
	end
	
	if not simSuccess or simResults ~= "" then return false, simResults end
	
	--table.insert( options, 3, "-q" )
	table.insert( options, 3, "--newline" )
	table.insert( options, 4, "--exec" ) table.insert( options, 5, "echo" )
	
	table.insert( self.q, {args = options, progress = progress, onFinish = onFinish} )
	
	if not self.instance then
		
		self.instance = coroutine.create(downloadQueue)
		
		coroutine.resume( self.instance, self )
		
	end
	
	return true
	
end

function ytdlp.setMaxThreading( self, num )
	
	self.threading.max = math.max( num, 1 )
	
	benbebase.debugVars.ytdlp_threads_max = self.threading.max
	
end

function create()
	
	benbebase.debugVars.ytdlp_threads_max, benbebase.debugVars.ytdlp_threads = 1, 0
	
	return setmetatable( {q = {}, instance = nil, threading = {count = 0, max = 1}}, ytdlp )
	
end

return create