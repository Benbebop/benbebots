local dir, fs = os.getenv('LOCALAPPDATA'), require("fs")

fs.mkdirSync(dir .. "\\benbebot\\")
fs.mkdirSync(dir .. "\\Temp\\benbebot\\")

local m = {}

function m.get( name, mode )
	mode = mode or "rb"
	return io.open(dir .. "\\benbebot\\" .. name, mode)
end

function m.write( name, str )
	local f = io.open(dir .. "\\benbebot\\" .. name, "wb")
	if not f then return false end
	f:write(str)
	f:close()
	return true
end

function m.append( name, str )
	local f = io.open(dir .. "\\benbebot\\" .. name, "a")
	if not f then return false end
	f:write(str)
	f:close()
	return true
end

function m.exists( name )
	local f = io.open(dir .. "\\benbebot\\" .. name, "r")
	local exists = f ~= nil
	if exists then f:close() end
	return exists
end

function m.read( name, s, e )
	local f = io.open(dir .. "\\benbebot\\" .. name, "rb")
	if not f then return false end
	local str = ""
	if s then
		f:seek(s - 1)
		str = f:read(e)
	else
		str = f:read("*a")
	end
	f:close()
	return str
end

function m.lines( name )
	return io.lines(dir .. "\\benbebot\\" .. name)
end

function m.modify( name, str, s, e )
	local f = io.open(dir .. "\\benbebot\\" .. name, "rb")
	local pre = f:read("*a")
	f:close()
	local f = io.open(dir .. "\\benbebot\\" .. name, "wb")
	f:write(pre:sub(1, s - 1) .. str .. pre:sub(e + 1, -1))
	f:close()
end

function m.replace( name, pattern, str )
	local f = io.open(dir .. "\\benbebot\\" .. name, "rb")
	local pre = f:read("*a")
	f:close()
	local f = io.open(dir .. "\\benbebot\\" .. name, "wb")
	f:write(pre:gsub(pattern, str))
	f:close()
end

function m.delete( name, pattern, str )
	os.remove(dir .. "\\benbebot\\" .. name)
end

local tempFile = {}
tempFile.__index = function( self, index )
	return tempFile[index] or self.io[index]
end

function tempFile.close( self )
	if not self.io then return end
	self.io:close()
	self.io = nil
	fs.unlinkSync(self.file)
end

function tempFile.path( self )
	return self.io and self.file
end

tempFile.__gc = function( self )
	tempFile.close( self )
end

local function setmt__gc(t, mt)
	local prox = newproxy(true)
	getmetatable(prox).__gc = function() mt.__gc(t) end
	t[prox] = true
	return setmetatable(t, mt)
end

function m.tempFile( name ) -- file that closes and deletes when garbage collected
	
	local name, ext = name:match("^(.-)%.([^%.]+)$")
	local index, file = 0, ""
	
	repeat index, file = index + 1, string.format( "%sTemp\\benbebot\\%s_%X.%s", dir, name, index, ext ) until not fs.exists( file )
	
	return setmt__gc({io = io.open(file, "wb"), file = file}, tempFile)
	
end

function m.init( data )
	for _,v in ipairs(data) do
		if v[1]:match("[/\\]$") then
			fs.mkdir(dir .. "\\benbebot\\" .. v[1]:gsub("[/\\]$", ""))
		else
			local testfor = m.get( v[1], "rb" )
			if not testfor then
				testfor = m.get( v[1], "wb" )
				if not testfor then error("could not initialize file " .. v[1]) end
				if type(v[2]) == "function" then
					v[2](testfor)
				else
					testfor:write(v[2] or "")
				end
			end
			testfor:close()
		end
	end
end

function m.directory(forward_slash)
	dir = os.getenv('LOCALAPPDATA')
	if forward_slash then
		return dir:gsub("\\", "/") .. "/benbebot/"
	else
		return dir .. "\\benbebot\\"
	end
end

function m.tempDirectory()
	return dir .. "\\Temp\\benbebot\\"
end

function m.path( file )
	dir = os.getenv('LOCALAPPDATA')
	return m.directory() .. file
end

return m