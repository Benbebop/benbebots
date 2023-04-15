local uv, fs, appdata = require("uv"), require("fs"), require("data")

require("./load-deps.lua")

local discordia = require("discordia")
local enums = discordia.enums
local clock = discordia.Clock()

local benbebot, familyGuy = discordia.Client(), discordia.Client()
benbebot._logger:setPrefix("BBB") familyGuy._logger:setPrefix("FLG") 
table.remove(benbebot._listeners.ready, 1) -- dont update commands

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
		
		interaction:reply("adding invite for " .. invite.guildName .. " to <#1089964247787786240>", true)
		benbebot:getChannel("1089964247787786240"):send("discord.gg/" .. invite.code)
		benbebot:info("added invite %s to servers channel", invite.code)

	end)
	
	-- server owner role
	
	local function add(guild)
		local owner = guild.client:getGuild("1068640496139915345"):getMember(guild.ownerId)
		if owner then owner:addRole("1068721381178617896") guild.client:info("added server owner role to %s", owner.name) end
	end
	benbebot:on("guildCreate", add)
	familyGuy:on("guildCreate", add)
	
	local function check(guild)
		local b, f = benbebot:getGuild(guild.id), familyGuy:getGuild(guild.id)
		if not (b and b.me or f and f.me) then
			local owner = guild.client:getGuild("1068640496139915345"):getMember(guild.ownerId)
			if owner then 
				owner:removeRole("1068721381178617896") 
				guild.client:info("removed server owner role from %s", owner.name) 
			else
				guild.client:error("failed to find owner of guild %s and remove server owner role", guild.name)
			end
		end
	end
	benbebot:on("guildDelete", check)
	familyGuy:on("guildDelete", check)
	
	-- soundclown
	
	local json, http = require("json"), require("coro-http")
	
	local STATION = "https://soundcloud.com/discover/sets/artist-stations:%s"
	local TRACK = "https://api-v2.soundcloud.com/tracks?ids=%s&client_id=%s"
	
	local function func()
		
		local res, body = http.request("GET", string.format(STATION, "634094352"))
		if not (res and (res.code == 200) and body) then benbebot:error("failed to get soundcloud station: %s", res.reason or tostring(res.code)) return end
		
		local stationContent = body:match("window.__sc_hydration%s*=%s*(%b[])")
		if not stationContent then benbebot:error("soundcloud station: could not locate hydration content") return end
		
		stationContent = json.parse(stationContent)
		if not stationContent then benbebot:error("soundcloud station: hydration content is not valid json") return end
		
		local stationPlaylist
		for _,v in ipairs(stationContent) do if v.hydratable == "systemPlaylist" then stationPlaylist = v.data end end
		if not stationPlaylist then benbebot:error("soundcloud station: could not locate hydratable systemPlaylist") return end
		if stationPlaylist.playlist_type ~= "ARTIST_STATION" then benbebot:error("soundcloud station: systemPlaylist is not an artist playlist: %s", stationPlaylist.playlist_type) return end
		
		local stationTracks = stationPlaylist.tracks
		if not stationTracks then benbebot:error("soundcloud station: playlist has no tracks") return end
		
		table.remove(stationTracks, 1) -- first result is always by the creator, get rid of it
		
		local client_id
		for url in body:gmatch("crossorigin%s*src=[\"']([^\"']+)") do -- im not very good at scraping, this works but is incredibly slow, whatever 
			local _, body = http.request("GET", url)
			client_id = body:match("[\"']client_id=([^\"']+)")
			if client_id then break end
		end
		if not client_id then benbebot:error("failed to scrape client_id") return end
		
		local res, body = http.request("GET", string.format(TRACK, stationTracks[math.random(#stationTracks)].id, client_id))
		if not (res and (res.code == 200) and body) then benbebot:error("failed to get soundcloud track: %s", res.reason or tostring(res.code)) return end
		
		local trackData = (json.parse(body) or {})[1]
		if not (trackData and trackData.permalink_url) then benbebot:error("soundcloud station: track content is not valid") return end
		
		benbebot:getChannel("1096581265932701827"):send(trackData.permalink_url)
		
	end
	
	clock:on("day", func)
	
	benbebot:on("ready", func)
	
end

benbebot:run("Bot " .. TOKENS.benbebot)
familyGuy:run("Bot " .. TOKENS.familyGuy)