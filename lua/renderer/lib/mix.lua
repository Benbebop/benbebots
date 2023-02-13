local m = {}

function m.mix(r1, g1, b1, r2, g2, b2) -- average color1 and color2
	r1, g1, b1 = tonumber(r1) or 0, tonumber(g1) or 0, tonumber(b1) or 0
	r2, g2, b2 = tonumber(r2) or 0, tonumber(g2) or 0, tonumber(b2) or 0
	
	local r = (r1 + r2) / 2
	local g = (g1 + g2) / 2
	local b = (b1 + b2) / 2
	
	return r, g, b
end

function m.hue(r1, g1, b1, r2, g2, b2) -- remove all color from color1 except color2
	r1, g1, b1 = tonumber(r1) or 0, tonumber(g1) or 0, tonumber(b1) or 0
	r2, g2, b2 = tonumber(r2) or 0, tonumber(g2) or 0, tonumber(b2) or 0
	
	d1 = math.sqrt( ( r1 ) ^ 2 + ( g1 ) ^ 2 + ( b1 ) ^ 2 )
	d2 = math.sqrt( ( r2 - r1 ) ^ 2 + ( g2 - g1 ) ^ 2 + ( b2 - b1 ) ^ 2 )
	
	local r = d1 - (1 - r2) * d2
	local g = d1 - (1 - g2) * d2
	local b = d1 - (1 - b2) * d2
	
	return r, g, b
end

function m.lighten(r1, g1, b1, r2, g2, b2) -- multiply by brightness of image
	r1, g1, b1 = tonumber(r1) or 0, tonumber(g1) or 0, tonumber(b1) or 0
	r2, g2, b2 = tonumber(r2) or 0, tonumber(g2) or 0, tonumber(b2) or 0

	local r = r1 * ( r2 + 1 )
	local g = g1 * ( g2 + 1 )
	local b = b1 * ( b2 + 1 )
	
	return r, g, b
end

function m.darken(r1, g1, b1, r2, g2, b2) -- multiply by darkness of image
	r1, g1, b1 = tonumber(r1) or 0, tonumber(g1) or 0, tonumber(b1) or 0
	r2, g2, b2 = tonumber(r2) or 0, tonumber(g2) or 0, tonumber(b2) or 0

	local r = r1 * r2
	local g = g1 * g2
	local b = b1 * b2
	
	return r, g, b
end

function m.alphaover(r1, g1, b1, r2, g2, b2, a1, a2) -- color1 over color2
	r1, g1, b1 = tonumber(r1) or 0, tonumber(g1) or 0, tonumber(b1) or 0
	r2, g2, b2 = tonumber(r2) or 0, tonumber(g2) or 0, tonumber(b2) or 0
	a1, a2 = tonumber(a1) or 0, tonumber(a2) or 0
	
	local a = a1 + a2 * ( 1 - a1 )
	
	local r = ( r1 * a1 + r2 * a2 * ( 1 - a1 ) ) / a
	local g = ( g1 * a1 + g2 * a2 * ( 1 - a1 ) ) / a
	local b = ( b1 * a1 + b2 * a2 * ( 1 - a1 ) ) / a
	
	return r, g, b, a
end

function m.alphaoverGC(r1, g1, b1, r2, g2, b2, a1, a2, y) -- color1 over color2
	r1, g1, b1 = tonumber(r1) or 0, tonumber(g1) or 0, tonumber(b1) or 0
	r2, g2, b2 = tonumber(r2) or 0, tonumber(g2) or 0, tonumber(b2) or 0
	a1, a2 = tonumber(a1) or 0, tonumber(a2) or 0
	y = tonumber(a1) or 0.5
	
	local a = a1 + a2 * ( 1 - a1 )
	
	local r = ( ( r1 ^ ( 1 / y ) * a1 + r2 ^ ( 1 / y ) * a2 * ( 1 - a1 ) ) / a ) ^ y
	local g = ( ( g1 ^ ( 1 / y ) * a1 + g2 ^ ( 1 / y ) * a2 * ( 1 - a1 ) ) / a ) ^ y
	local b = ( ( b1 ^ ( 1 / y ) * a1 + b2 ^ ( 1 / y ) * a2 * ( 1 - a1 ) ) / a ) ^ y
	
	return r, g, b, a
end

return m