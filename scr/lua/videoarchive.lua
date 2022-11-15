local fs, uv = require("fs"), require("uv")

local wrap = coroutine.wrap

--[[local function normChar(b)
	if b == 45 then
		return 1
	elseif b < 91 then
		return b - 63
	elseif b == 95 then
		return 28
	else
		return b - 68
	end
end

local function expChar(b)
	if b == 1 then
		return 45
	elseif b < 28 then
		return b + 63
	elseif b == 28 then
		return 95
	else
		return b - 68
	end
end

local function encodeId( id ) --compress 11 byte youtube id into 9 byte string
	local str = ""
	for p=0,2 do --divide the 72 bits of the final string into 3, 24 bit, chunks
		local num = 0
		for c=p*4+1,math.min((p+1)*4+1,11) do --each character in the id can be represented with 6 bits
			local b = normChar(string.byte(id:sub(c,c)))
			num = bit32.replace(num, b, c-p*4, 6)
		end
		for b=0,2 do --add resulting 3 byte chunk to string
			str = str .. string.char(bit32.extract(num, b * 8, 8))
		end
	end
	return str
end

local function decodeId( str )
	local value = 0
	for i=1,9 do
		bit32.replace( value, string.byte( str:sub(i,i) ), i * 8, 8 )
	end
end]]

local va = {}
va.__index = function( self, index )
	return va[index] or self.vars[index] or self.settings[index]
end
va.__newindex = function(self, index, value)
	if value == nil then value = false end
	if self.settings[index] == nil then return end
	self.settings[index] = value
end

function open( archive )
	
	local stats = fs.statSync(archive .. "index.db")
	
	return setmetatable({
		dir = archive, 
		vars = {entries = math.floor(stats.size / 22)}, 
		settings = {qualityMode = false, videoMaxSize = false, audioMaxSize = false}, 
		downloadSession = nil, 
		queue = {}
	}, va)
	
end

--[[archive spesification

index.db
FOREACH{
	string[9] - encoded videoid
	byte[1] - video format
	short[2] - archive index
	long[4] - position in archive
	long[4] - length
}

]]

local format_index = {"mp4", "3gp", "flv", "webm"}
local max_archive_size, max_archive_count, max_entry_size = 2 ^ 26, 2 ^ 8, 8e+6

function va.addVideo( self, id, callback, progress )
	
	if self.downloadSession then return false, "download already in progress" end
	
	local index = fs.openSync( self.dir .. "index.db", "r+" )
	local stats = fs.fstatSync( index )
	local exists, cursor = false, 0
	
	while cursor < stats.size do
		local vid = fs.readSync(index, 11, cursor)
		
		if vid == id then exists = true break end
		
		cursor = cursor + 22
	end
	
	if exists then return false, "entry already exists" end
	
	local stdout = uv.new_pipe(false)
	
	local q, mV, mA = (self.settings.qualityMode == "worst") and "worst" or "best", self.settings.videoMaxSize and ("[filesize<" .. self.settings.videoMaxSize .. "]") or "", self.settings.audioMaxSize and ("[filesize<" .. self.settings.audioMaxSize .. "]") or ""
	
	self.downloadSession = uv.spawn("bin/yt-dlp.exe", {stdio = {nil, stdout}, args = {"-o", self.dir .. "temp.%(ext)s", "-f", q .. "video" .. mV .. "+" .. q .. "audio" .. mA, "--recode-video", "mp4", id}}, function()
		
		self.downloadSession = nil
		
		local videoContent = fs.readFileSync( self.dir .. "temp.webm" )
		fs.unlinkSync( self.dir .. "temp.webm" )
		
		if not videoContent then wrap(callback)( false, "failed to download file" ) return end
		
		local i, size, output = 0, 0, 0
		
		repeat
			local file = self.dir .. "archive_" .. i .. ".db"
			output = fs.openSync( file, "r+" ) or fs.openSync( file, "w+" )
			size = fs.readSync( output, 5, 0 )
			if size == "" then
				size = 5 fs.writeSync( output, 0, string.pack( "I5", size ) )
			else
				size = string.unpack( "I5", size )
			end
			
			if size < max_archive_size then break end
			
			fs.closeSync( output )
			
			i = i + 1
			
		until i > max_archive_count
		
		local contentLength = #videoContent
		
		if contentLength > max_entry_size then fs.closeSync( output ) fs.closeSync( index ) wrap(callback)( false, "recoded file too large (>8mb)" ) return end
		
		fs.writeSync( output, 0, string.pack("I5", size + contentLength) )
		
		fs.write(output, size, videoContent, function()
			
			fs.closeSync(output)
			
			wrap(callback)( true, math.floor(cursor / 22) + 1 )
			
		end)
		
		fs.writeSync( index, cursor, string.pack("c11BHLL", id, 4, i, size, contentLength) )
		
		self.vars.entries = self.vars.entries + 1
		
		fs.closeSync( index )
		
	end)
	
	if progress then
		local stage = nil
	
		stdout:read_start(function(_, d)
			if d then
			if d:match("^%s*%[youtube%]") and stage ~= 1 then
				stage = 1
				wrap(progress)(1, "fetching video information")
			elseif d:match("^%s*%[download%]") and stage ~= 2 then
				stage = 2
				wrap(progress)(2, "downloading video components")
			elseif d:match("^%s*%[Merger%]") and stage ~= 3 then
				stage = 3
				wrap(progress)(3, "merging video components to single video")
			elseif d:match("^%s*%[VideoConverter%]") and stage ~= 4 then
				stage = 4
				wrap(progress)(4, "recoding video")
			end
			end
		end)
	end
	
	return true
	
end

function va.addVideoSync( self, id, progress )
	
	local thread = coroutine.running()
	
	local success, result = va.addVideo( self, id, function( success, result )
		
		coroutine.resume(thread, success, result)
		
	end, progress)
	
	if not success then
		return success, result
	else
		return coroutine.yield()
	end
	
end

function va.removeVideo( self, index )
	
	local indexFile = fs.openSync( self.dir .. "index.db", "r+" )
	local entry = fs.readSync(indexFile, 22, (index - 1) * 22)
	
	if not entry then return false, "id does not exist" end
	
	local _, _, archiveIndex, removedOffset, removedLength = string.unpack("c11BHLL", entry)
	
	-- MODIFY ARCHIVE --
	local archive = fs.openSync( self.dir .. "archive_" .. archiveIndex .. ".db", "r+" )
	local blockSize = fs.fstatSync( archive ).blksize or 4096
	local fin = string.unpack( "I5", fs.readSync( archive, 5, 0 ) )
	local cursor, sync = removedOffset, math.ceil( removedOffset / blockSize ) * blockSize - removedOffset
	
	fs.writeSync( archive, cursor, fs.readSync( archive, sync, cursor + removedLength ) )
	cursor = cursor + sync
	
	while cursor < fin do
		
		fs.writeSync( archive, cursor, fs.readSync( archive, blockSize, cursor + removedLength ) )
		cursor = cursor + blockSize
		
	end
	
	fs.writeSync( archive, 0, string.pack("I5", fin - removedLength ) )
	
	fs.closeSync( archive )
	
	-- MODIFY INDEX --
	local indexPos = (index - 1) * 22
	fs.writeSync( indexFile, indexPos, string.rep( string.char(0), 22 ) )
	fin = fs.fstatSync( indexFile ).size
	
	cursor = 0
	
	while cursor < fin do
		
		local entry = fs.readSync(indexFile, 22, cursor)
		
		local _, _, index, offset = string.unpack("c11BHLL", entry)
		
		if index == archiveIndex and offset > removedOffset then
			
			if cursor > indexPos then
				
				fs.writeSync( indexFile, cursor - 22, entry )
				fs.writeSync( indexFile, cursor - 8, string.pack("L", offset - removedLength ) )
				
			else
			
				fs.writeSync( indexFile, cursor + 14, string.pack("L", offset - removedLength ) )
			
			end
			
		elseif cursor > indexPos then
			
			fs.writeSync( indexFile, cursor - 22, entry )
			
		end
		
		cursor = cursor + 22
		
	end
	
	fs.ftruncateSync(indexFile, fin - 22)
	
	fs.closeSync( indexFile )
	
	return true
	
end

function va.getVideo( self, index )
	
	local indexFile = fs.openSync( self.dir .. "index.db", "r" )
	local entry = fs.readSync(indexFile, 22, (index - 1) * 22)
	fs.closeSync( indexFile )
	
	if not entry then return false, "id does not exist" end
	
	local id, extension, archiveIndex, offset, length = string.unpack("c11BHLL", entry)
	
	local archive = fs.openSync( self.dir .. "archive_" .. archiveIndex .. ".db", "r" )
	local content = fs.readSync(archive, length, offset)
	fs.closeSync( archive )
	
	return true, {id = id, ext = format_index[extension]}, content
	
end

function va.getIndex( self, id )
	
	local index = fs.openSync( self.dir .. "index.db", "r+" )
	local size = fs.fstatSync( index ).size
	local exists, cursor = false, 0
	
	while cursor < size do
		local vid = fs.readSync(index, 11, cursor * 22)
		
		if vid == id then exists = true break end
		
		cursor = cursor + 1
	end
	
	fs.closeSync(index)
	
	if exists then
		
		return cursor + 1
		
	else
		
		return false
		
	end
	
end

local baseCharacters = "_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
local prime, base = 4294967291, #baseCharacters

function va.uniqueId( self )
	
	local x = uv.gettimeofday()
	
    local i, returnString = 0, ""
    local remainder
    while x ~= 0 do
        i = i + 1 -- Compound this is luau
		x, remainder = math.floor(x / base), x % base + 1
        -- remainder = x % base + 1
        -- x = math.floor(x / base)
        returnString = baseCharacters:sub(remainder, remainder) .. returnString
    end
    return returnString
end

return open