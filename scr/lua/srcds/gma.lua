local fs, json = require("fs"), require("json")

local NUL = string.char(0)
local function readString( file, offset )
	local content = {}
	
	local c = fs.readSync( file, 1, offset )
	repeat
		offset = offset + 1
		
		if c == NUL then break end
		
		table.insert(content, c)
		
		c = fs.readSync( file, 1, offset )
	until not c
	
	return table.concat( content ), offset
end

local gma = {}
gma.__index = gma

local sunpack = string.unpack

function gma.new( self, file )
	file = fs.openSync( file or self, "r" )
	
	local self = {}
	
	if fs.readSync( file, 4, 0 ) ~= "GMAD" then return false, "file is not a gmad file" end
	
	self.version = sunpack( "B", fs.readSync( file, 1, 4 ) )
	
	self.steamid, self.timestamp = sunpack( "I8I8", fs.readSync( file, 16, 5 ) ) -- steamid is unused
	
	local offset
	self.title, offset = readString( file, 22 )
	self.json, offset = readString( file, offset )
	self.author, offset = readString( file, offset )
	
	self.addonVersion = sunpack( "L", fs.readSync( file, 4, offset ) )
	offset = offset + 4
	
	self.entries = {}
	local eOffset = 0
	
	while sunpack( "L", fs.readSync( file, 4, offset ) ) > 0 do
		offset = offset + 4
		local entry = {}
		
		entry.strName, offset = readString( file, offset )
		entry.size = sunpack( "I8", fs.readSync( file, 8, offset ) ) offset = offset + 8
		entry.CRC = sunpack( "L", fs.readSync( file, 4, offset ) ) offset = offset + 4
		entry.offset = eOffset
		eOffset = eOffset + entry.size
		
		table.insert(self.entries, entry)
		
	end
	
	self.contentOffset = offset
	self.fd = file
	
	return setmetatable( self, gma )
	
end

function gma.getMaps( self )
	local maps = {}
	
	for i,v in ipairs( self.entries ) do
		if v.strName:sub(-4, -1) == ".bsp" then
			table.insert(maps, v.strName:match("([^\\/]+)%.bsp$"))
		end
	end
	
	return maps
	
end

function gma.getGamemodes( self )
	
end

function gma.extractFile( self, file )

end

function gma.close( self )
	fs.closeSync(self.fd)
end

return gma