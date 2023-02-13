local class = {}

local metaballs = {}

class.draw = function( x, y, range )
	local value, red, green, blue = 0, 0, 0, 0
	for i,v in ipairs(metaballs) do
		value = value + v.r / math.sqrt( (x-v.x)^2 + (y-v.y)^2 )
		red = red + v.color.r * value
		green = green + v.color.g * value
		blue = blue + v.color.b * value
	end
	if value > range then
		return red, green, blue
	else
		return 0
	end
end

class.new = function( x0, y0, r, color )
	local index = #metaballs + 1
	
	metaballs[index] = { x = x0, y = y0, r = r, color = color }
	
	local metaball = {}
	
	metaball.setpos = function( x, y )
		metaballs[index].x = x
		metaballs[index].y = y
	end
	
	metaball.setradius = function( x, y )
		metaballs[index].x = x
		metaballs[index].y = y
	end
	
	metaball.setcolor = function( x, y )
		metaballs[index].x = x
		metaballs[index].y = y
	end
	
	return setmetatable( metaball, metametaball ), index
end

class.remove = function( index )
	metaballs[index] = nil
end

return setmetatable( class, {
	__metatable = "the metatable is locked"
} )