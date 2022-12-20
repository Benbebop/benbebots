local server_id = "822165179692220476"

local commandModule = require("../command")

function main( client, guild, l_config )
	
	-- FISH REACT SOMEGUY --
	
	local fish = string.pack( "BBB", 0xEE, 0x80, 0x99 )
	
	client:on("messageCreate", function( message )
		
		if message.author.id == "565367805160062996" then
		
			message:addReaction(fish)
		
		end
	
	end)
	
	-- porn poster --
	
	client:on("messageCreate", function(message)
	
		if message.author.id == "406268244048085002" then
			if message.attachment or message.embed or message.content:match("https?://[^%s]+") then
				message:delete()
			end
		end
	
	end )
	
	-- GARRYS MOD --

	local gmodCommands = commandModule( "gmod" )

	client:on("messageCreate", function(message)
	
		if message.channel.id == "1012114692401004655" then
			gmodCommands:run( message )
		end
	
	end )
	
	-- https://partner.steamgames.com/doc/api/ISteamUGC#AddDependency
	c = gmodCommands:new( "addAddon", function( message, args )
		
	end )
	
end

return {server_id, main}