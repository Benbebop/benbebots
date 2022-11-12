local uv, fs, timer, appdata = require("uv"), require("fs"), require("timer"), require("../appdata")

local max_file_size = 25e+6

local resumeYielded = benbebase.resumeYielded

local ytdlp = {}
ytdlp.__index = ytdlp

local dlDirectory = appdata.tempDirectory() .. "ytdlp/"
fs.mkdirSync(dlDirectory)

local nul = string.char( 0 )
local dlTemplate = table.concat( {"%(progress.status)s","%(info.title)s","%(info.ext)s","%(progress.filename)s","%(progress.tmpfilename)s","%(progress.downloaded_bytes)s","%(progress.total_bytes)s","%(progress.total_bytes_estimate)s","%(progress.elapsed)s","%(progress.eta)s","%(progress.speed)s","%(progress.fragment_index)s","%(progress.fragment_count)s",""}, string.char( 31 ) )
local statusIndex = {{"status"}, {"title"}, {"extention"}, {"filename"}, {"tmpfilename"}, {"downloadedBytes", true}, {"totalBytes", true}, {"totalBytesEstimate", true}, {"elapsed", true}, {"eta", true}, {"speed", true}, {"fragmentIndex"}, {"fragmentCount"}}

local function download( self, work, id )
	
	table.insert( work.args, 1, "-o" ) table.insert( work.args, 2, dlDirectory .. id .. "_%(id)s_%(extractor_key)s.%(ext)s" )
	table.insert( work.args, 1, "--progress-template" ) table.insert( work.args, 2, dlTemplate )
	
	local results, errors = "", ""
	
	local stdout, stderr = uv.new_pipe(false), uv.new_pipe(false)
	
	local proc = uv.spawn( "bin/yt-dlp.exe", {stdio = {nil, stdout, stderr}, args = work.args}, function() resumeYielded( self.dlThreads[id] ) end )
	
	stdout:read_start( function(err, data)
		if err then
			resumeYielded( self.dlThreads[id] )
		elseif data then
			results = results .. data
		end
	end)
	stderr:read_start( function(err, data)
		if err then
			resumeYielded( self.dlThreads[id] )
		elseif data then
			errors = errors .. data
		end
	end)
	
	local update
	
	if work.progress then
		
		local u = function()
			results = #results > 1000 and results:sub(-500, -1) or results
			results = results:match("([^\n\r]+)%s*$") or ""
			local status, i = {}, 0
			for v in results:gmatch( "[^\31]+" ) do
				i = i + 1
				local index = statusIndex[i]
				if not index then break end
				if v == "NA" then
					status[index[1]] = nil
				elseif index[2] then
					status[index[1]] = tonumber(v)
				else
					status[index[1]] = v
				end
			end
			status.status = status.status or "not started"
			local size = status.totalBytes or status.totalBytesEstimate or status.downloadedBytes or 0
			if size >= max_file_size then
				errors = "file too large"
				resumeYielded( self.dlThreads[id] )
				return
			end
			if status then
				coroutine.wrap(work.progress)( status )
			end
		end
		
		update = timer.setInterval(2500, u)
		u()
		
	end
	
	local id_str = tostring( id )
	local id_length = #id_str
	
	if errors == "" then coroutine.yield() end
	
	proc:kill()
	
	timer.clearInterval( update )
	
	local file = results:match("([^\"]+)\"%s*$")
	
	if work.onFinish then
		if errors ~= "" then
			work.onFinish( errors )
		elseif not file then
			work.onFinish( "somethin broke idk" )
		else
			work.onFinish( false, file )
		end
	end
	
	fs.unlink( file )
	
	table.remove( self.dlThreads, id )
	
	if self.mainThread then assertResume( self.mainThread ) end
	
end

local function runQueue( self )
	
	repeat
		
		local work = self.q[1]
		table.remove(self.q, 1)
		
		local i = #self.dlThreads + 1
		
		self.dlThreads[i] = coroutine.create(download)
		coroutine.resume( self.dlThreads[i], self, work, i )
		
		while #self.dlThreads >= self.maxThreads do coroutine.yield() end
		
	until #self.q <= 0
	
	self.mainThread = nil
	
end

function ytdlp.queue( self, options, allowNSFW, progress, onFinish )
	
	local simErrors, simOutput = "", ""
	
	--check if valid video
	do
		
		local thread = coroutine.running()
		
		local simOptions = {table.unpack(options)}
		table.insert( simOptions, 1, "--print" ) table.insert( simOptions, 2, "extractor_key" )
		
		local stdout, stderr = uv.new_pipe(), uv.new_pipe()
		
		local proc = uv.spawn( "bin/yt-dlp.exe", {stdio = {nil, stdout, stderr}, args = simOptions}, function() resumeYielded( thread ) end )
		
		stdout:read_start( function(err, data) if err then simErrors = "internalerror:ERRPIPE(" .. err .. ")" proc:kill() resumeYielded( thread ) elseif data then simOutput = simOutput .. data end end)
		stderr:read_start( function(err, data) if err then simErrors = "internalerror:ERRPIPE(" .. err .. ")" proc:kill() resumeYielded( thread ) elseif data then simErrors = simErrors .. data end end)
		
		coroutine.yield()
		
	end
	
	if simErrors ~= "" then return false, simResults end
	
	--table.insert( options, 3, "-q" )
	table.insert( options, 1, "--newline" )
	table.insert( options, 1, "--exec" ) table.insert( options, 2, "echo" )
	
	table.insert( self.q, {args = options, progress = progress, onFinish = onFinish} )
	
	if not self.mainThread then
		
		self.mainThread = coroutine.create(runQueue)
		
		coroutine.resume( self.mainThread, self )
		
	end
	
	return true, #self.q
	
end

function ytdlp.setMaxThreading( self, num )
	
	self.maxThreads = math.max( num, 1 )
	
	benbebase.debugVars.ytdlp_threads_max = self.maxThreads
	
end

function create()
	
	benbebase.debugVars.ytdlp_threads_max, benbebase.debugVars.ytdlp_threads = 1, 0
	
	return setmetatable( {q = {}, mainThread = nil, dlThreads = {}, maxThreads = 1}, ytdlp )
	
end

return create