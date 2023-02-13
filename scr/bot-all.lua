local thread = require("thread")

local bots = {"bot.lua", "bot-family.lua"}

for i,v in ipairs(bots) do
	
	thread.start(function( file )
		require(file)
	end, v)
	
end