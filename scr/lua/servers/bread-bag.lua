local server_id = "822165179692220476"

local http, json = require("coro-http"), require("json")

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
	
	-- VERIFY IP ADDRESSES --
	
	local rdap = require("../api/rdap.lua")
	
	client:on("messageCreate", function(message)
		if (message.guild or {}).id ~= server_id then return end
		local p1, p2, p3, p4 = message.content:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
		p1, p2, p3, p4 = tonumber(p1), tonumber(p2), tonumber(p3), tonumber(p4)
		
		if not (p1 and p2 and p3 and p4) then return end
		
		if p1 <= 255 and p2 <= 255 and p3 <= 255 and p4 <= 255 then
			local exists = rdap.ipExists( table.concat({ p1, p2, p3, p4 }, ".") )
			
			if exists or exists == nil then return end
			--[[https.get({
				hostname = "rdap.arin.net",
				path = "registry/ip/" .. table.concat({ p1, p2, p3, p4 }, ".")
			}, function( ... )
				p(...)
			end)]]
		end
		
		message:reply({file = "resource/invalidip.jpg"})
		
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