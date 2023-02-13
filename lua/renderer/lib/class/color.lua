local class = {}

class.new = function( red, green, blue )
	if red ~= red then red = 0 end
	if green ~= green then green = 0 end
	if blue ~= blue then blue = 0 end
	
	local color, colormeta, red, green, blue = {}, {}, red, green or red, blue or green or red
	
	red, green, blue = math.min( red or 0, 1 ), math.min( green or 0, 1 ), math.min( blue or 0, 1 )
	local data = { r = red, g = green, b = blue }
	
	color.get255 = function()
		return math.floor( data.r * 255 ), math.floor( data.g * 255 ), math.floor( data.b  * 255 )
	end
	
	color.get100 = function()
		return math.floor( data.r * 1000 ) / 10, math.floor( data.g * 1000 ) / 10, math.floor( data.b * 1000 ) / 10
	end
	
	color.get = function()
		return data.r, data.g, data.b
	end
	
	color.set = function(r, g, b)
		r, g, b = r, g or r, b or g or r
		data.r, data.g, data.b = r, g, b
	end
	
	color.average = function( toAverage )
		if toAverage then
			local r, g, b, r1, g1, b1 = data.r, data.g, data.b, toAverage.get()
			return (r + r1) / 2, (g + g1) / 2, (b + b1) / 2
		else
			return 0, 0, 0
		end
	end
	
	colormeta.__index = function( tbl, key )
		if key == "red" or key == "r"  then
			return data.r
		elseif key == "green" or key == "g"  then
			return data.g
		elseif key == "blue" or key == "b"  then
			return data.b
		end
	end
	
	colormeta.__tostring = function()
		return tostring( data.r ) .. ", " .. tostring( data.g ) .. ", " .. tostring( data.b )
	end
	
	colormeta.__type = "color"
	
	colormeta.__metatable = "the metatable is locked"
	
	return setmetatable( color, colormeta )
end

return setmetatable( class, {
	__metatable = "the metatable is locked"
} )