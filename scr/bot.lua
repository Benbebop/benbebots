require("./lua/benbase")

local token, srcds, statistics, fs = require("./lua/token"), require("./lua/source-dedicated-server"), require("./lua/statistics"), require("fs")

-- LOAD SERVER SPECIFIC STUFF --

local serverScripts = {}

for f,t in fs.scandirSync( "lua/servers/" ) do
	if t == "file" and f:sub(-#(".lua"), -1) == ".lua" then
		table.insert(serverScripts, require("./lua/servers/" .. f) or {})
	end
end

-- INITIALISE --

require("./lua/config")("benbebot")

srcds.setDirectory( "C:/dedicatedserver/garrysmod/" )

local discordia = require("discordia")
local client = discordia.Client()

benbebase.initialise( client, "benbebot" )
local output = benbebase.output
local commandModule = require("./lua/command")
local commands = commandModule( "bbb", "benbebot" )

-- RUN SERVER SPECIFIC STUFF --

for _,v in ipairs(serverScripts) do
	local guild = client:getGuild( v[1] )
	if guild then
		v[2]( client, guild, config[v[1]] )
	end
end

-- COMMANDS --

client:on("messageCreate", function(message)
	
	commands:run( message, client.user )
	
end )

local configCheck, allowedGuilds

do 
	local json = require("json")
	configCheck = json.parse(fs.readFileSync("resource/config-update.json"))
	allowedGuilds = json.parse(fs.readFileSync("resource/approved-server.json"))
end

config:setDefaults( configCheck )

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
c:userPermission("manageWebhooks")

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
c:requiredPermissions( "attachFiles" )

c = commands:new( "sex", function( message )
	
	message.member:ban()
	
end )
c:requiredPermissions( "banMembers" )

-- MISC --

-- EVERYTHING

local everythings = statistics( 12, 4, "L" )

local runningEveryones = 0

client:on("messageCreate", function( message )
	
	if not message.guild then return end
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

client:on("messageCreate", function( message )
	
	if message.member and message.content:match("https?://grabify%.link/") then
		message.member:setNickname("im trying to steal your ip")
		grabsSent:increase( 1 )
	end
	
end)

client:on("ready", function()
	
	benbebase.sendPrevError()
	
	client.guilds:forEach(function(guild)
		local allowed = false
		for _,v in ipairs(allowedGuilds) do
			if guild.id == v then
				allowed = true
				break
			end
		end
		if not allowed then
			guild:leave()
		end
	end)
	
	allowedGuilds = nil
	
	statistics( 20, 4, "L" ):increase( 1 )
	
end)

client:run('Bot ' .. token.getToken( 1 ))