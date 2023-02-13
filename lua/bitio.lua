-- allows for bit read and write --

local bitio = {}

local bitfile = {}
bitfile.__index = function( self, index )
	if not self then return end
	return bitfile[index] or self.io[index]
end

local function unpackByte( c )
	if not c then return {false,false,false,false,false,false,false,false} end
	c = string.byte(c)
	local b = {}
	
	for i=7,0,-1 do
		local int,frac = math.modf( c / 2 ^ i )
		c = frac * 2 ^ i
		
		b[i + 1] = int ~= 0
	end
	
	return b
	
end

local function packByte( b )
	local c = 0
	
	for i=0,7 do
		
		c = c + (b[i + 1] and 1 or 0) * 2 ^ i
		
	end
	
	return string.char(c)
	
end

function bitio.open( file, mode )
	mode = (mode == "r" and "rb") or (mode == "w" and "wb") or mode
	
	local file = io.open(file, mode)
	
	if not file then return end
	
	local bits = unpackByte( file:read(1) ) file:seek("cur", -1)
	
	return setmetatable({io = file, subcursor = 1, currentBits = bits}, bitfile)
	
end

local function grab( self, count )
	count = count or 1
	
	local s = self.io:read(count)
	
	self.io:seek("cur", -count)
	
	return s
	
end

local function set( self, str )
	
	self.io:write(str) self.io:seek("cur", -#str)
	
end

function bitfile.seek( self, mode, offset )
	
	self.io:seek( mode, offset )
	self.subcursor = 1
	self.currentBits = unpackByte( grab(self, 1) )
	
end

local function nxt( self ) bitfile.seek( self, "cur", 1 ) end

function bitfile.write( self, str )
	
	self.io:write( str )
	self.subcursor = 1
	self.currentBits = unpackByte( grab(self, 1) )
	
end

function bitfile.writeBit( self, bit )
	bit = (bit == 1) or (bit == true)
	
	self.currentBits[self.subcursor] = bit
	self.subcursor = self.subcursor + 1
	
	set( self, packByte(self.currentBits) )
	
	if self.subcursor > 8 then nxt(self) end
	
end

function bitfile.writeNum( self, num, length )
	local bits = {}
	
	for i=length - 1,0,-1 do
		local int,frac = math.modf( num / 2 ^ i )
		num = frac * 2 ^ i
		
		bits[i + 1] = int ~= 0
	end
	
	for i=1,length do
		
		self.currentBits[self.subcursor] = bits[i]
		self.subcursor = self.subcursor + 1
		
		if self.subcursor > 8 then bitfile.write( self, packByte( self.currentBits ) ) end
		
	end
	
	set( self, packByte( self.currentBits ) )
	
end

function bitfile.writeStr( self, str, charLength )
	str, charLength = tostring(str), charLength or 8
	local estr = ""
	
	for i=1,#str do
		
		local num = string.byte( str:sub(i,i) )
		
		for i=charLength - 1,0,-1 do --TODO: turn this into a function shared between writeNum and writeStr
			local int,frac = math.modf( num / 2 ^ i )
			num = frac * 2 ^ i
		
			self.currentBits[self.subcursor] = int ~= 0
			self.subcursor = self.subcursor + 1
			if self.subcursor > 8 then
				estr = estr .. packByte( self.currentBits )
				nxt( self )
			end
		end
		
	end
	
	self.io:write(str)
	set( self, packByte( self.currentBits ) )
	
end

function bitfile.readBit( self )
	
	local b = self.currentBits[self.subcursor]
	self.subcursor = self.subcursor + 1
	
	if self.subcursor > 8 then nxt(self) end
	
	return self.currentBits[self.subcursor]
	
end

function bitfile.readNum( self, length )
	local n = 0
	
	for i=0,length - 1 do
		
		n = n + (bitfile.readBit( self ) and 1 or 0) * 2 ^ i
		
	end
	
	return n
	
end

function bitfile.readStr( self, length, charLength )
	charLength = charLength or 8
	local str = ""
	
	for i=1,length do str = str .. string.char(bitfile.readNum( self, charLength )) end
	
	return str
	
end

function bitfile.seekBit( self, mode, offset )
	
	local bytePos = math.floor( offset / 8 )
	
	local bitPos = offset - bytePos * 8
	
	self.subcursor = (mode == "cur" and self.subcursor or 0) + bitPos
	
	if bytePos > 0 then
		
		self.io:seek(mode, bytePos)
		self.currentBits = unpackByte( grab(self, 1) )
		
	end
	
	return self.io:seek("cur") * 8 + bitPos
	
end

function bitfile.close( self )
	
	self.io:close()
	
	self = nil
	
end

return bitio