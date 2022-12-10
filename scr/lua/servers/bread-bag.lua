local server_id = "822165179692220476"

local commandModule = require("../command")

local function main( client, guild )
	
	-- FISH REACT SOMEGUY --
	
	local fish = string.pack( "BBB", 0xEE, 0x80, 0x99 )
	
	client:on("messageCreate", function( message )
		
		if message.author.id == "565367805160062996" then
		
			message:addReaction(fish)
		
		end
	
	end)
	
	-- GARRYS MOD --

	local gmodCommands = commandModule( "gmod" )

	client:on("messageCreate", function(message)
	
		if message.channel.id == "1012114692401004655" then
			gmodCommands:run( message )
		end
	
	end )

	c = gmodCommands:new( "start", function( message, _, argStr )
		srcds.killServer()
		local success,err = srcds.launch( argStr or "Sandbox", function()
			client:getChannel("1012114692401004655"):send({embed = {description = "server shutdown"}})
		end)
		if success then 
			client:getChannel("1012114692401004655"):send({embed = {title = "Benbebot Gmod Server Started", description = "you can use this link to join: " .. srcds.getJoinUrl()}})
			message:reply("started server")
		else
			message:reply("error starting server: " .. err)
		end
	end )
	c:userPermission("manageWebhooks")
	c:setHelp( "<gamemode>", "start gmod server" )

	c = gmodCommands:new( "gamemodes", function( message )
		message:reply( table.concat( srcds.getGamemodes(), ", " ) )
	end )
	c:setHelp( nil, "get a list of all gmod gamemodes supported by benbebot" )

	c = gmodCommands:new( "gamemodeinfo", function( message, args )
		
	end )
	c:setHelp( "<map>", "get info about a gamemode" )

	c = gmodCommands:new( "getmaps", function( message )
		message:reply( table.concat( srcds.getMaps(), ", " ) )
	end )
	c:setHelp( nil, "get a list of all current gmod server maps" )

	c = gmodCommands:new( "mapinfo", function( message, args )
		
	end )
	c:setHelp( "<map>", "get info about a map" )

	c = gmodCommands:new( "setmap", function( message, args )
		local reply = message:reply("setting gmod server map")
		local success = srcds.setMap( args[1] )
		if success == 1 then
			reply:setContent("successfully set gmod server map")
		else
			reply:setContent("failed to set gmod server map")
		end
	end )
	c:userPermission("manageWebhooks")
	c:setHelp( "<map>", "set the map of the current gmod server" )
	
end

return {server_id, main}