local class = {}

function intToLetter( integer ) -- there is probably a more efficient way of doing this, fix some point in the future
	if not integer then return nil end
	local base25, str = tonumber( tostring( integer ), 25 ), ""
	
	for c in tostring(base25):gmatch(".") do
		if c == "0" then str = str .. "a"
		elseif c == "1" then str = str .. "b"
		elseif c == "2" then str = str .. "c"
		elseif c == "3" then str = str .. "d"
		elseif c == "4" then str = str .. "e"
		elseif c == "5" then str = str .. "f"
		elseif c == "6" then str = str .. "g"
		elseif c == "7" then str = str .. "h"
		elseif c == "8" then str = str .. "i"
		elseif c == "9" then str = str .. "j"
		elseif c == "A" then str = str .. "k"
		elseif c == "B" then str = str .. "l"
		elseif c == "C" then str = str .. "m"
		elseif c == "D" then str = str .. "n"
		elseif c == "E" then str = str .. "o"
		elseif c == "F" then str = str .. "p"
		elseif c == "G" then str = str .. "q"
		elseif c == "H" then str = str .. "r"
		elseif c == "I" then str = str .. "s"
		elseif c == "J" then str = str .. "t"
		elseif c == "K" then str = str .. "u"
		elseif c == "L" then str = str .. "v"
		elseif c == "M" then str = str .. "w"
		elseif c == "N" then str = str .. "x"
		elseif c == "O" then str = str .. "y"
		elseif c == "P" then str = str .. "z"
		end
	end
	
	return str
end

function createMatrixData( tbl )
	local data = {}
	
	if not pcall( ipairs, tbl ) then error( "table not a numeric array" ) end
	
	for i,v in ipairs( tbl ) do
		if not pcall( ipairs, v ) then error( "matrix collum " .. i .. " not a numeric array" ) end
		for l,k in ipairs( v ) do
			data[intToLetter( i ) .. l] = k
		end
	end
	
	return data
end

class.new = function( tbl )
	local matrix, matrixmeta = {}, {}
	
	if not tbl then tbl = {{}} end
	
	local data = createMatrixData( tbl )
	
	matrix.set = function( value, xindex, yindex )
		data[intToLetter( xindex ) .. yindex] = value
		return value
	end
	
	matrix.get = function( xindex, yindex )
		return data[intToLetter( xindex ) .. yindex]
	end
	
	matrix.getData = function()
		return data
	end
	
	local cursor = {x = 1, y = 1}
	
	matrix.itterate = function()
		local index, item = cursor, data[intToLetter( cursor.x ) .. cursor.y]
		if data[intToLetter( cursor.x + 1 ) .. cursor.y] then
			cursor.x = cursor.x + 1
		elseif data[intToLetter( 1 ) .. cursor.y + 1] then
			cursor.x = 1
			cursor.y = cursor.y + 1
		elseif cursor.final then
			cursor = {x = 1, y = 1}
			return nil
		else
			cursor = {x = 1, y = 1, final = true}
		end
		return index, item
	end
	
	matrixmeta.__add = function( self, addend )
		if type(multiplicand) == "number" then
			for i,v in matrix.itterate do
				matrix.set( v + multiplicand, i.x, i.y )
			end
		elseif type(multiplicand) == "userdata" and multiplicand.__type == "2dmatrix" then
			for i,v in matrix.itterate do
				matrix.set( v + multiplicand:get(i.x, i.y), i.x, i.y )
			end
		end
	end
	
	matrixmeta.__sub = function( self, addend )
		if type(multiplicand) == "number" then
			for i,v in matrix.itterate do
				matrix.set( v - multiplicand, i.x, i.y )
			end
		elseif type(multiplicand) == "userdata" and multiplicand.__type == "2dmatrix" then
			for i,v in matrix.itterate do
				matrix.set( v - multiplicand:get(i.x, i.y), i.x, i.y )
			end
		end
	end
	
	matrixmeta.__mul = function( self, multiplicand )
		if type(multiplicand) == "number" then
			for i,v in matrix.itterate do
				matrix.set( v * multiplicand, i.x, i.y )
			end
		elseif type(multiplicand) == "userdata" and multiplicand.__type == "2dmatrix" then
			for i,v in matrix.itterate do
				matrix.set( v * multiplicand:get(i.x, i.y), i.x, i.y )
			end
		end
	end
	
	matrixmeta.__div = function( self, multiplicand )
		if type(multiplicand) == "number" then
			for i,v in matrix.itterate do
				matrix.set( v / multiplicand, i.x, i.y )
			end
		elseif type(multiplicand) == "userdata" and multiplicand.__type == "2dmatrix" then
			for i,v in matrix.itterate do
				matrix.set( v / multiplicand:get(i.x, i.y), i.x, i.y )
			end
		end
	end
	
	matrixmeta.__pow = function( self, multiplicand )
		if type(multiplicand) == "number" then
			for i,v in matrix.itterate do
				matrix.set( v ^ multiplicand, i.x, i.y )
			end
		elseif type(multiplicand) == "userdata" and multiplicand.__type == "2dmatrix" then
			for i,v in matrix.itterate do
				matrix.set( v ^ multiplicand:get(i.x, i.y), i.x, i.y )
			end
		end
	end
	
	matrixmeta.__index = data
	
	matrixmeta.__tostring = function()
		local str = ""
		for i,v in pairs(data) do
			str = str .. tostring( v ) .. "\t"
		end
		return str
	end
	
	matrixmeta.__concat = function( self, append )
		return matrixmeta.__tostring() .. tostring( append )
	end
		
	matrixmeta.__type = "2dmatrix"
	
	matrixmeta.__metatable = "the metatable is locked"
	
	return setmetatable( matrix, matrixmeta )
end

return setmetatable( class, {
	__metatable = "the metatable is locked"
})