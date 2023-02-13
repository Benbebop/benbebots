local m = {}

function m.invert(r0, g0, b0) -- invert rgb
	r0, g0, b0 = tonumber(r0) or 0, tonumber(g0) or 0, tonumber(b0) or 0
	
	local r = 1 - r0
	local g = 1 - g0
	local b = 1 - b0
	
	return r, g, b
end

function m.posterize(r0, g0, b0, c) -- reduce colorspace ( maximum 255 )
	r0, g0, b0 = tonumber(r0) or 0, tonumber(g0) or 0, tonumber(b0) or 0
	c = 2 ^ math.max( math.min( tonumber(c) or 0, 8 ), 0 )
	
	local r = math.floor( r0 * c ) / c
	local g = math.floor( g0 * c ) / c
	local b = math.floor( b0 * c ) / c
	
	return r, g, b
end

return m