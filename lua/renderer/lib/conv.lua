local m = {}

function m.hsv(r1, g1, b1) -- RGB to HSV
	r, g, b = tonumber(r1) or 0, tonumber(g1) or 0, tonumber(b1) or 0
	
	return h, s, v
end

return m