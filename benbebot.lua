local discordia = require("discordia") require("discordia-interactions") require("discordia-commands")
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
	
	local serverChannel, serverMessage
	
	local gmodCommands = {
		command:addOption( enums.applicationCommandOptionType.subCommand, "stop" ):setDescription("kill and exit the running gmod server"):setEnabled(false)
	}
	
	local gms = require("garrys-mod-server")( "A:\\benbebots\\server\\garrysmod\\" )
	gms:setToken( readToken(2) )
	
	server:callback( function( interaction, args )
		interaction:replyDeferred()
		start:setEnabled( false )
		local gamemode, err = gms:start( args.gamemode, args.map )
		
		if err then interaction:reply({embed = {description = err, footer = prevError.error_footer}}, true) start:setEnabled( true ) return end
		
		interaction:reply({embed = {title = "Starting Garrysmod Server", description = "please wait"}})
		local m = interaction:getReply()
		
		local function updateMessage()
			local console = gms:getConsole() or ""
			if console ~= store then
				store = console
				m:setEmbed({title = "Starting Garrysmod Server", description = "```\n" .. (store:match("([^\n]+)%s*$") or "starting srcds") .. "\n```"})
			end
		end
		
		updateMessage()
		local t = timer.setInterval(1000, function() coroutine.wrap(updateMessage)() end)
		
		local joinString, err = gms:waitForServer( 120 )
		
		timer.clearInterval(t)
		
		if err then m:setEmbed({title = "There was an error starting your server", description = err, footer = prevError.error_footer}) start:setEnabled( true ) return end
		
		for _,v in ipairs(gmodCommands) do v:setEnabled(true) end
		
		serverChannel = interaction.channel
		
		serverMessage = serverChannel:send({content = " <@&1068664164786110554> ", embed = {
			title = "Started Garrysmod Server", description = string.format("To join manually you can type `%s` into the gmod console.\nYou can also use this link to launch gmod and join automatically:\nsteam://run/4000//%s/", joinString, querystring.urlencode("+" .. joinString)),
			fields = {
				{name = "Gamemode", value = gamemode.name},
				{name = "Map", value = gms.map},
				{name = "Players", value = string.format("%d/%d", gms.playerCount, gms.playerMax)}
			}}
		})
		
		m:delete()
	end )
	
	local function updatePlayerCount()
		if not serverMessage then return end
		serverMessage.fields[3].value = string.format("%d/%d", gms.playerCount, gms.playerMax)
		serverMessage:setEmbed( serverMessage.embed )
	end
	
	gms:on( "playerJoined", function( name )
		serverChannel:send({embed = {
			description = string.format("`%s` joined the server", name)
		}})
		updatePlayerCount()
	end )
	
	gms:on( "playerLeft", function( name )
		serverChannel:send({embed = {
			description = string.format("`%s` left the server", name)
		}})
		updatePlayerCount()
	end )
	
	gms:on( "exit", function()
		if not (serverChannel and serverMessage) then return end
		serverMessage.embed.description = "this server has already shutdown, sorry if ya missed it!"
		serverMessage:setEmbed( serverMessage.embed )
		serverMessage = nil
		
		serverChannel:send({embed = {description = "garrysmod server shutdown", footer = prevError.error_footer}})
		serverChannel = nil
	end )
	
	local addons = command:addOption( enums.applicationCommandOptionType.subCommandGroup, "addons" ):setDescription("manage server addons")
	
	local addAddon = addons:addOption( enums.applicationCommandOptionType.subCommand, "add" ):setDescription("add a new addon to the garrysmod server")
	local removeAddon = addons:addOption( enums.applicationCommandOptionType.subCommand, "remove" ):setDescription("add a new addon to the garrysmod server")
	
	server = start:addOption( enums.applicationCommandOptionType.subCommand, "minecraft" ):setDescription("new minecraft server")
	server:callback( function( interaction )
		print("2")
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
	
end

client:on("ready", function()
	local err = prevError.getError("benbebot")
	if err then client:getChannel( "1068652454838812682" ):send(err) end
end)

client:run("Bot " .. readToken(1))