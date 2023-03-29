local uv, fs, appdata = require("uv"), require("fs"), require("data")

require("./loadDeps.lua")

local discordia = require("discordia")
local enums = discordia.enums

local benbebot, familyGuy = discordia.Client(), discordia.Client()
benbebot._logger:setPrefix("BBB") familyGuy._logger:setPrefix("FLG") 

benbebot:defaultCommandCallback(function(interaction)
	interaction:reply({embed = {
		description = "couldnt find command, [please report this error](https://github.com/Benbebop/benbebots/issues)"
	}})
end)

do -- BENBEBOTS SERVER --
	
	-- servers channel

	local inv = benbebot:newSlashCommand("addinvite", "1068640496139915345"):setDescription("add an invite")
	inv:addOption(enums.applicationCommandOptionType.string, "invite"):setDescription("invite url/code"):setRequired(true)
	
	local url = require("url")

	inv:callback(function(interaction, args)
		interaction:replyDeferred(true)

		local code = url.parse(args.invite or "").path:match("%w+$")
		if not code then interaction:reply("invalid invite url", true) return end

		local invite = benbebot:getInvite(code)
		if not invite then interaction:reply("invalid invite", true) return end
		
		if interaction.user.id ~= "459880024187600937" then
			
			if interaction.user ~= invite.inviter then interaction:reply("you cannot add an invite that you did not create", true) return end

			local bGuild = benbebot:getGuild(invite.guildId)
			local fGuild = familyGuy:getGuild(invite.guildId)
			if not (bGuild and bGuild.me or fGuild and fGuild.me) then interaction:reply("server does not have any benbebots", true) return end
			
		end
		
		interaction:reply("adding invite for " .. invite.guildName .. " to <#1089964247787786240>")
		benbebot:getChannel("1089964247787786240"):send("discord.gg/" .. invite.code)

	end)
	
end

benbebot:run("Bot " .. TOKENS.benbebot)
familyGuy:run("Bot " .. TOKENS.familyGuy)
