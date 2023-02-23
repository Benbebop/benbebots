local discordia = require("discordia") require("discordia-interactions") require("discordia-commands")
local timer = require("timer")
local readToken = require("read-token")
local querystring = require("querystring")
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

do -- SERVER COMMAND --
	local serverChannel
	
	local command = client:newSlashCommand("server", "1068640496139915345"):setDescription("start a server")
	local start = command:addOption( enums.applicationCommandOptionType.subCommandGroup, "start" ):setDescription("start a new server")
	
	local server = start:addOption( enums.applicationCommandOptionType.subCommand, "garrysmod" ):setDescription("new garrysmod server")
	server:addOption( enums.applicationCommandOptionType.string, "gamemode" ):setDescription("gamemode to start the server on"):setRequired( true )
	server:addOption( enums.applicationCommandOptionType.string, "map" ):setDescription("map to start the server on")
	
	local gmodCommands = {
		command:addOption( enums.applicationCommandOptionType.subCommand, "stop" ):setDescription("kill and exit the running gmod server"):setEnabled(false)
	}
	
	local gms = require("garrys-mod-server")( "A:\\benbebots\\server\\garrysmod\\" )
	gms:setToken( readToken(2) )
	
	server:callback( function( interaction, args )
		start:setEnabled( false )
		local gamemode, err = gms:start( args.gamemode, args.map )
		
		if err then interaction:reply({embed = {description = err, footer = error_footer}}, true) start:setEnabled( true ) return end
		
		interaction:reply({embed = {title = "Starting Garrysmod Server", description = "please wait"}})
		local m = interaction:getReply()
		
		local store = gms:getConsole() or ""
		m:setEmbed({title = "Starting Garrysmod Server", description = "```\n" .. store:match("([^\n]+)%s*$") .. "\n```"})
		
		local t = timer.setInterval(1000, function() coroutine.wrap(function()
			local console = gms:getConsole() or ""
			if console ~= store then
				store = console
				m:setEmbed({title = "Starting Garrysmod Server", description = "```\n" .. store:match("([^\n]+)%s*$") .. "\n```"})
			end
		end)() end)
		
		local joinString, err = gms:waitForServer( 120 )
		
		timer.clearInterval(t)
		
		if err then m:setEmbed({title = "There was an error starting your server", description = err, footer = error_footer}) start:setEnabled( true ) return end
		
		for _,v in ipairs(gmodCommands) do v:setEnabled(true) end
		
		serverChannel = interaction.channel
		
		m:reply({content = " <&@1078165125598547988> ", embed = {
			title = "Started Garrysmod Server", description = string.format("To join manually you can type `%s` into the gmod console.\nYou can also use this link to launch gmod and join automatically:\nsteam://run/4000//%s/", joinString, querystring.urlencode("+" .. joinString)),
			fields = {
				{name = "Gamemode", value = gamemode.name}
			}}
		})
		
		gms:onExit( function()
			serverChannel:send({embed = {description = "garrysmod server shutdown", footer = error_footer}})
		end )
	end )
	
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
	<@&1072698350836662392> :sleeping: - get pinged when the bot's pfps are updated]]
		)
	end)

	local rolesIndex = {
		["\240\159\165\185"] = "1075196966654451743",
		["\240\159\142\174"] = "1068664164786110554",
		["\240\159\135\181\240\159\135\177"] = "1075245976543056013",
		["\240\159\152\180"] = "1072698350836662392",
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

client:run("Bot " .. readToken(1))