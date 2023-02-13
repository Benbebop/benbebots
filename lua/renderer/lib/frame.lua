local ini = require( "./lua/renderer/lib/ini" )

local settings = ini.load( "lua/renderer/settings.ini" )

settings.render.fps = settings.render.fps * 2

local library = {}

local callbacks = {}

library.onFrame = function( callback )
	if not type(callback) == "function" then error() end
	local position = #callbacks + 1
	callbacks[position] = callback
	return position
end

library.run = function( frames, frameOne )
	if frameOne then frameOne = 1 else frameOne = 0 end
	local latestFrame, frameCount, start = frameOne, frameOne, os.clock()
	repeat
		local cl = os.clock()
		if (settings.render.fps == 0) or ((cl - latestFrame) * settings.render.fps >= 1) then
			for i in ipairs(callbacks) do
				callbacks[i]( frameCount, cl )
			end
			latestFrame, frameCount = cl, frameCount + 1
		end
	until frameCount >= frames
	return os.clock() - start
end

return setmetatable( library, {
	__metatable = "the metatable is locked"
})