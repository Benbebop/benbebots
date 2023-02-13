math.randomseed(os.clock())

function render( x, y, frame, i, calc, xres, yres, env )
	env.x = tonumber(x) or 0
	env.y = tonumber(y) or 0
	env.h = tonumber(xres) or 0
	env.w = tonumber(yres) or 0
	local success, r, g, b = pcall(load(calc, nil, "t", env))
	if success then
		return r, g, b
	else
		return 0
	end
end

return render
