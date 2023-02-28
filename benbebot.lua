local discordia = require("discordia") require("load-extensions") --require("production-mode")
local timer = require("timer")
local readToken = require("read-token")
local querystring = require("querystring")
local prevError = require("previous-error")
local enums = discordia.enums

local client = discordia.Client()
client:enableAllIntents()

local error_footer = {text = "Report this error at https://github.com/Benbebop/benbebots/issues."}

if false then -- DOWNLOAD COMMAND --
	local command = client:newSlashCommand("download"):setDescription("download a video from a variety of sites")
	local option = command:addOption( enums.applicationCommandOptionType.string, "url" ):setDescription("url to the video you want to download")

	local ytdlp, urlParse, queryString = require("yt-dlp"), require("url").parse, require("querystring")

	command:callback( function( interaction, args )
		local session = ytdlp( nil, args.url or "" )
		
		local err = session:parseUrl()
		
		if err then interaction:reply( err, true ) return end
		
		local formats, err = session:listFormats()
		
		if not formats then interaction:reply( err, true ) return end
	end )

end

do -- GAME SERVER COMMAND --
	
	local command = client:newSlashCommand("server", "1068640496139915345"):setDescription("start a server")
	local start = command:addOption( enums.applicationCommandOptionType.subCommandGroup, "start" ):setDescription("start a new server")
	
	local server = start:addOption( enums.applicationCommandOptionType.subCommand, "garrysmod" ):setDescription("new garrysmod server")
	server:addOption( enums.applicationCommandOptionType.string, "gamemode" ):setDescription("gamemode to start the server on"):setRequired( true )
	server:addOption( enums.applicationCommandOptionType.string, "map" ):setDescription("map to start the server on")
	
	local gms = require("garrys-mod-server")( "A:\\benbebots\\server\\garrysmod\\" )
	gms:setToken( readToken(2) )
	
	local serverChannel, serverInit, serverMessage
	
	local gmodCommands = {
		command:addOption( enums.applicationCommandOptionType.subCommand, "stop" ):setDescription("kill and exit the running gmod server"):setEnabled(false):callback(function() gms:kill() end)
	}
	
	server:callback( function( interaction, args )
		interaction:replyDeferred()
		start:setEnabled( false )
		local err = gms:start( args.gamemode, args.map )
		
		interaction:reply({embed = {
			title = "Starting Your Garry's Mod Server",
			description = "```\n```"
		}})
		
		serverInit = interaction:getReply()
		serverChannel = serverInit.channel
	end )
	
	local inprogress = false
	gms:on("consoleOutput", function(line)
		if (not serverInit) or inprogress then return end
		inprogress = true
		serverInit.embed.description = string.format("```\n%s\n```", line)
		serverInit:setEmbed(serverInit.embed)
		inprogress = false
	end)
	
	gms:on("ready", function(gamemode, joinString)
		if not (serverInit and serverChannel) then return end
		serverInit:delete()
		
		serverMessage = serverChannel:send({embed = {
			title = "Garry's Mod Server Started",
			description = string.format("To join manually you can type `%s` into the gmod console.\nYou can also use this link to launch gmod and join automatically:\nsteam://run/4000//%s/", joinString, querystring.urlencode("+" .. joinString)),
			fields = {
				{name = "Gamemode", value = gamemode.name, inline = true},
				{name = "Map", value = gms.map, inline = true},
				{name = "Players", value = string.format("%d/%d", gms.playerCount, gms.playerMax)}
			}
		}})
	end)
	
	local function updatePlayerCount()
		serverMessage.embed.fields[3].value = string.format("%d/%d", gms.playerCount, gms.playerMax)
		serverMessage:setEmbed(serverMessage.embed)
	end
	
	gms:on("playerJoined", function(name)
		if not (serverChannel and serverMessage) then return end
		updatePlayerCount()
		serverChannel:send({embed = {description = string.format("`%s` joined", name)}})
	end)
	
	gms:on("playerLeft", function(name)
		if not (serverChannel and serverMessage) then return end
		updatePlayerCount()
		serverChannel:send({embed = {description = string.format("`%s` left", name)}})
	end)
	
	gms:on("exit", function()
		start:setEnabled( true )
		for _,v in ipairs(gmodCommands) do v:setEnabled(false) end
		if not (serverChannel and serverMessage) then serverMessage, serverChannel = nil, nil return end
		serverMessage.embed.description = "this server has already shutdown, sorry if ya missed it!"
		serverMessage:setEmbed( serverMessage.embed )
		serverMessage = nil
		
		serverChannel:send({embed = {description = "garrysmod server shutdown", footer = prevError.error_footer}})
		serverChannel = nil
	end )
	
end

do -- AUTO ROLES --
	
	client:on("ready", function()
		client:getChannel("1075203623073632327"):getMessage("1077041796779094096"):setContent(
[[@everyone You know how this works
	<@&1075196966654451743> :face_holding_back_tears: - major updates involving the bots
	<@&1068664164786110554> :video_game: - game server events
	<@&1075245976543056013> :flag_pl: - polls involving this server
	<@&1072698350836662392> :sleeping: - get pinged when the bot's pfps are updated
	<@&1078400699802587136> :skull: - get pinged whenever i feel the urge to kill]]
		)
	end)

	local rolesIndex = {
		["\240\159\165\185"] = "1075196966654451743",
		["\240\159\142\174"] = "1068664164786110554",
		["\240\159\135\181\240\159\135\177"] = "1075245976543056013",
		["\240\159\152\180"] = "1072698350836662392",
		["\240\159\146\128"] = "1078400699802587136",
	}
	
	local function add(_, messageId, hash, userId)
		if messageId == "1077041796779094096" then
			local role = rolesIndex[hash]
			if not role then return end
			client:getGuild("1068640496139915345"):getMember(userId):addRole(role)
		end
	end
	
	local function remove(channel, messageId, hash, userId)
		if messageId == "1077041796779094096" then
			local role = rolesIndex[hash]
			if not role then return end
			client:getGuild("1068640496139915345"):getMember(userId):removeRole(role)
		end
	end
	
	client:on("reactionAddUncached", add)
	client:on("reactionAdd", function(reaction, userId) add(reaction.message.channel, reaction.message.id, reaction.emojiHash, userId) end)
	
	client:on("reactionRemoveUncached", remove)
	client:on("reactionRemove", function(reaction, userId) remove(reaction.message.channel, reaction.message.id, reaction.emojiHash, userId) end)
	
	client:on("guildCreate", function(guild)
		local member = client:getGuild("1068640496139915345"):getMember(guild.ownerId)
		if member then
			member:addRole("1068721381178617896")
		end
	end)
	
	client:on("guildDelete", function(guild)
		local member = client:getGuild("1068640496139915345"):getMember(guild.ownerId)
		if member then
			local multiguild = false
			
			member:removeRole("1068721381178617896")
		end
	end)
	
end

client:on("ready", function()
	local err = prevError.getError("benbebot")
	if err then client:getChannel( "1068652454838812682" ):send(err) end
end)

client:run("Bot " .. readToken(1))