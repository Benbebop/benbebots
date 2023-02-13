local ini = require( "./lua/renderer/lib/ini" )

local settings = ini.load( "lua/renderer/settings.ini" )

local library = {}

local colorFormat = "[38;5;%dm"

library.send = function( filename )
	os.execute("bin\\ffplay lua\\renderer\\frames\\ppm\\" .. filename .. ".ppm")
end

library.run = function( filename, leadingZero )
	if (leadingZero > 9 or leadingZero < 0) or (math.floor(leadingZero) ~= leadingZero) then
		error("leadingZero must be a positive integer and less then 10")
	end
	if settings.render.frames > 0 then
		os.execute("bin\\ffplay -noborder -loop 0 lua\\renderer\\frames\\ppm\\" .. filename .. "%0" .. leadingZero .. "d.ppm")
	end
end

library.save = function( pMatrix, name, toClose, res )
	local file, prevlineindex = io.open("lua\\renderer\\frames\\ppm\\" .. name .. ".ppm", "w+"), 1
	file:write("P3\n" .. res[1] .. " " .. res[2] .. "\n255\n")
	local prevCursor = {}
	for i,v in pMatrix.itterate do
		local r, g, b = 0, 0, 0
		if v then
			r, g, b = v:get255()
		end
		local append = " "
		if i.x == settings.render.xres then
			append = "\n"
		end
		file:write(string.format("% 4d% 4d% 4d", math.max( r, 0 ), math.max( g, 0 ), math.max( b, 0 )) .. append)
		prevCursor = i
	end
	
	file:close()
	
	os.execute("bin\\ffmpeg -hide_banner -loglevel error -y -i lua\\renderer\\frames\\ppm\\" .. name .. ".ppm lua\\renderer\\frames\\" .. name .. ".png")
end

return setmetatable( library, {
	__metatable = "the metatable is locked"
})
