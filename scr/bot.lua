require("./lua/benbase")

local token, srcds, statistics, fs = require("./lua/token"), require("./lua/source-dedicated-server"), require("./lua/statistics"), require("fs")

require("./lua/config")("benbebot")

srcds.setDirectory( "C:/dedicatedserver/garrysmod/" )

-- INITIALISE --
local discordia = require("discordia")
local client = discordia.Client()

benbebase.initialise( client, "benbebot" )
local output = benbebase.output
local commandModule = require("./lua/command")
local commands = commandModule( "bbb", "benbebot" )

-- COMMANDS --

client:on("messageCreate", function(message)
	
	commands:run( message )
	
end )

local configCheck

do 
	local json = require("json")
	configCheck = json.parse(fs.readFileSync("resource/config-update.json"))
end

local c = commands:new( "config", function( message, args )
	local templateVal = configCheck[args[1]]
	if templateVal ~= nil then
		local value = args[2]
		local templateType = type(templateVal)
		if templateType == "boolean" then
			value = value == "true"
		elseif templateType == "number" then
			value = tonumber(value)
		end
		local cfg = config[message.guild.id]
		local preval = cfg[args[1]]
		cfg[args[1]] = value
		message:reply("set config `" .. args[1] .. "` from `" .. tostring(preval) .. "` to `" .. tostring(value) .. "`")
	else
		message:reply("config does not exist")
	end
	
end )
c:addPermission("manageWebhooks")
c:addRequirement("guild")

local ytdlp = require("./lua/api/ytdlp")()

ytdlp:setMaxThreading( 10 )

local formatOptions = {webm = {"webm"}, mp4 = {"mp4"}, mov = {"mov"}, mp3 = {"mp3", true}, wav = {"wav", true}, ogg = {"ogg", true}}

local inQueue = {}

local downloadStats = statistics( 0, 12, "LI8" )

c = commands:new( "download", function( message, arguments )
	
	if inQueue[message.author.id] then
		
		message:reply("you cannot queue more then one video at once")
		
	else
	
		inQueue[message.author.id] = true
		
		local place = #inQueue
		
		local reply = message:reply({
			content = "queueing your video",
			reference = {
				message = message,
				mention = true,
			}
		})
		
		local args = {}
		
		local format, url = arguments[2] and arguments[1], arguments[2] or arguments[1]
		local audio
		
		if format then
			format, audio = unpack(formatOptions[format] or {})
			
			if not format then inQueue[message.author.id] = nil reply:setContent( "invalid media format" ) return end
			
			table.insert( args, "--recode-video" ) table.insert( args, format )
		end
		
		table.insert( args, "-f" ) table.insert( args, audio and "ba[filesize<25M]*/b[filesize<25M]*/b" or "bv[filesize<25M]*+ba/b[filesize<25M]*/b" )
		
		table.insert( args, url )
		
		local dots = benbebase.activeIndicator( 3 )
		
		local bytes = 0
		
		local success, result = ytdlp:queue( args, false, function( stage )
			
			if stage.status == "downloading" then
				local str
				if stage.title then
					str = string.format("downloading your video \"%s\" ", stage.title)
				else
					str = "downloading your video "
				end
				str = str .. string.format("(%s) %s", stage.extention, benbebase.niceSize( stage.downloadedBytes ) )
				if stage.totalBytes then
					str = str .. string.format(" out of %s (%d%%)", benbebase.niceSize( stage.totalBytes ), stage.downloadedBytes / stage.totalBytes )
				elseif stage.totalBytesEstimate then
					str = str .. string.format(" out of ~%s (%d%%)", benbebase.niceSize( stage.totalBytesEstimate ), stage.downloadedBytes / stage.totalBytesEstimate )
				end
				if stage.speed then
					str = str .. string.format(" at %s/S", benbebase.niceSize( stage.speed ) )
				end
				if stage.eta then
					str = str .. string.format(", %s remaining", benbebase.niceTime( stage.eta ) )
				end
				str = str .. string.format(" %s", dots() )
				reply:setContent( str )
				bytes = stage.totalBytes or stage.totalBytesEstimate
			elseif stage.status ~= "not started" then
				reply:setContent( stage.status )
			else
				reply:setContent( "getting ready to download your video" )
			end
			
		end, function( err, file )
			
			inQueue[message.author.id] = nil
		
			if err then
				reply:setContent( "there was an error downloading your video: " .. err )
			else
				reply:setContent( "your video has finished downloading" )
				reply.channel:send( {
					file = file,
					reference = {
						message = message,
						mention = true,
					}
				})
				local s = fs.statSync( file )
				downloadStats:increase( 1, bytes or s.size )
			end
		
		end )
		
		if not success then inQueue[message.author.id] = nil reply:setContent( result ) return end
		
		reply:setContent("your video has been queued (in place " .. place .. ")")
		
	end
	
end )
c:setHelp( "[<format> <quality>] <url>", "download a video from a variety of sites, for a list of supported sites see https://ytdl-org.github.io/youtube-dl/supportedsites.html" )

c = commands:new( "sex", function( message )
	
	message.member:ban()
	
end )

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
c:addPermission("manageWebhooks")
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
c:addPermission("manageWebhooks")
c:setHelp( "<map>", "set the map of the current gmod server" )

-- MISC --

-- FISH REACT SOMEGUY --

client:on("messageCreate", function( message )
	
	if message.author.id == "565367805160062996" then
		
		message:addReaction("\xEE\x80\x99")
		
	end
	
end)

-- EVERYTHING

local everythings = statistics( 12, 4, "L" )

local runningEveryones = 0

client:on("messageCreate", function( message )
	
	if not config[message.guild.id].enableEverything then return end
	
	local toPing = false
	
	if message.content:find("@%\\?everything") then
		toPing = true
	elseif message.guild and not message.author.bot then
		for user in message.mentionedUsers:iter() do
			local member = message.guild:getMember(user.id)
			
			if member.name:lower():match("^%s*everything%s*$") then toPing = true break end
		end
	end
	
	if toPing then
		if runningEveryones >= 5 then return end
		runningEveryones = runningEveryones + 1
		local c = message.channel local g = c.guild
		c:send("https://tenor.com/view/peng-ping-gif-25714269")
		local str = ""
		local iters = {{g.roles:iter(), "<@&", ">"}, {g.members:iter(), "<@", ">"}, {g.textChannels:iter(), "<#", ">"}, n = 3}
		repeat
			local index = math.random(iters.n)
			local rand = iters[index]
			local role = rand[1]()
			
			if not role then table.remove(iters, index) iters.n = iters.n - 1 else
				local sequence = rand[2] .. role.id .. rand[3]
			
				if #str + #sequence > 2000 then
					c:send(str)
					str = sequence
				else
					str = str .. sequence
				end
			end
		until iters.n <= 0
		if #str > 0 then c:send(str) end
		runningEveryones = math.max(runningEveryones - 1, 0)
		everythings:increase( 1 )
	end
	
end)

-- GRABIFY

local grabsSent = statistics( 16, 4, "L" )

client:on("messageCreate", function( message )
	
	if message.member and message.content:match("https?://grabify%.link/") then
		message.member:setNickname("im trying to steal your ip")
		grabsSent:increase( 1 )
	end
	
end)

client:on("ready", function()
	
	benbebase.sendPrevError()
	
	statistics( 20, 4, "L" ):increase( 1 )
	
end)

client:run('Bot ' .. token.getToken( 1 ))