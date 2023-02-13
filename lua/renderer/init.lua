function run( xres, yres, calc, channel )
	local dir = "./lua/renderer/"
	local ini, renderScript, Matrix, Color, Frame, Display, Metaball, enviroment = require( dir .. "lib/ini" ), require( dir .. "render" ), require( dir .. "lib/class/matrix" ), require( dir .. "lib/class/color" ), require( dir .. "lib/frame" ), require( dir .. "lib/display" ), require( dir .. "lib/class/metaball" ), require( dir .. "env" )
	
	local env = enviroment( channel )

	local success, err = pcall(load(calc, nil, "t", env))
	
	if not success then
		return false, err
	end

	local settings = ini.load( dir .. "settings.ini" )
	local dmode = settings.misc.debug

	local subMatrix = Matrix.new()

	if settings.render.ssaa <= 1 then settings.render.ssaa = 1 end

	local duration

	Frame.onFrame(function( frame )
		local tIndex = 0
		local stamp1 = os.clock()
		for y=1,yres do
			for x=1,xres do
				tIndex = tIndex + 1
				subMatrix.set( Color.new( renderScript( x, y, frame, tIndex, calc, xres, yres, env ) ), x, y )
			end
		end
		local pMatrix, res = true, settings.render.ssaa
		if res > 1 then
			pMatrix = Matrix.new()
			for y=1,yres / res do
				for x=1,xres / res do
					local blockColor = Color.new()
					for i=1,res do
						for l=1,res do
							blockColor = Color.new( blockColor.average( subMatrix.get( x * res + i, y * res + l ) ) )
						end
					end
					pMatrix.set( blockColor, x, y)
				end
			end
		else
			pMatrix = subMatrix
		end
		duration = math.floor( ( os.clock() - stamp1 ) * 100 )
		local frameIndex = string.format("frame%04d", frame)
		Display.save( pMatrix, frameIndex, true, {xres, yres} )
		io.write("rendered ", frame, " in ", duration, " ms\n")
	end)

	Frame.run( settings.render.frames, true )

	--Display.run( "frame", 4 )
	
	return true, "lua/renderer/frames/frame0001.png", duration
end

return run