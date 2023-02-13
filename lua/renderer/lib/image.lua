local m = {}

local function readPbm( file )
	local line = io.lines( file )
	local mode = line():match("P%d")
	local w, h = line():match("^(%d+)%s*(%d+)")
	local str = line()
	for l in line do 
		str = str .. l
	end
	return str, {w, h}, mode
end

local troll = {readPbm( "lua/renderer/img/troll.pbm" )}

function m.imgtroll( x, y, w, h )
	local content, d = troll[1], troll[2]
	local index = math.floor( ( w * y + x ) * ( w / d[1] ) ) 
	local v = tonumber( content:sub(index, index) )
	return v, v, v
end

return m