function create( channel )
	local env = {}

	for i,v in pairs(math) do
		env[i] = v
	end
	
	for i,v in pairs(require("./lua/renderer/lib/mix")) do
		env[i] = v
	end
	
	for i,v in pairs(require("./lua/renderer/lib/conv")) do
		env[i] = v
	end
	
	for i,v in pairs(require("./lua/renderer/lib/col")) do
		env[i] = v
	end
	
	for i,v in pairs(require("./lua/renderer/lib/image")) do
		env[i] = v
	end

	for i,v in pairs(require("./lua/renderer/lib/extMath")) do
		env[i] = v
	end
	
	env.randomseed = nil

	local funcs = "./lua/renderer/lib/functions/"

	env.perlin = require(funcs .. "perlin").fbm

	env.metaball = require("./lua/renderer/lib/class/metaball")

	env.color = require("./lua/renderer/lib/class/color")
	
	--local printCount = 0
	
	-- env.print = function( str )
		-- printCount = printCount + 1
		-- if printCount < 10 then
			-- channel:send(tostring(str))
		-- end
	-- end
	
	env.x = 0
	env.y = 0
	
	env.h = 0
	env.w = 0
	
	return env
end

return create