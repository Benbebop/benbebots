require("./lua/benbase")

local token, srcds, cfg = require("./lua/token"), require("./lua/source-dedicated-server"), require("./lua/config")

cfg.load()
cfg.update()

p(config)

srcds.setDirectory( "C:/dedicatedserver/garrysmod/" )

-- INITIALISE --
local discordia = require("discordia")
local client = discordia.Client()

benbebase.initialise( client, "benbebot" )
local output = benbebase.output
local commands = require("./lua/command")( "bbb", "benbebot" )

-- COMMANDS --

client:on("messageCreate", function(message)
	
	commands:run( message )
	
end )

local c = commands:new( "config", function( message, args )
	if config[args[1]] ~= nil then
		local value = args[2]
		if value == "true" then
			value = true
		elseif value == "false" then
			value = false
		elseif tonumber(value) then
			value = tonumber(value)
		end
		local preval = config[args[1]]
		config[args[1]] = value
		cfg.save()
		message:reply("set config `" .. args[1] .. "` from `" .. tostring(preval) .. "` to `" .. tostring(value) .. "`")
	else
		message:reply("config does not exist")
	end
	
end )
c:addPermission("manageWebhooks")

local ytdlp = require("./lua/api/ytdlp")()

ytdlp:setMaxThreading( 10 )

local formatOptions = {webm = {"webm"}, mp4 = {"mp4"}, mov = {"mov"}, mp3 = {"mp3", true}, wav = {"wav", true}, ogg = {"ogg", true}}

local inQueue = {}

local c = commands:new( "download", function( message, arguments )
	
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
			end
		
		end )
		
		if not success then inQueue[message.author.id] = nil reply:setContent( result ) return end
		
		reply:setContent("your video has been queued (in place " .. place .. ")")
		
	end
	
end )
c:setHelp( "[<format> <quality>] <url>", "download a video from a variety of sites, for a list of supported sites see https://ytdl-org.github.io/youtube-dl/supportedsites.html" )

local c = commands:new( "gmod", function( message, args )
	
	message:reply(srcds:sbpLink())
	
end )
c:setHelp( "[<format> <quality>] <url>", "" )

local c = commands:new( "sex", function( message )
	
	message.member:ban()
	
end )

-- MISC --

-- FISH REACT SOMEGUY --

client:on("messageCreate", function( message )
	
	if message.author.id == "565367805160062996" then
		
		message:addReaction("")
		
	end
	
end)

-- EVERYTHING

local runningEveryones = 0

client:on("messageCreate", function( message )
	
	if not config.enableEverything then return end
	
	if message.content:find("@everything") then
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
	end
	
end)

client:on("ready", function()
	
	benbebase.sendPrevError()
	
	--assert(srcds.launch( "sandbox" ))
	
	print("done")
	
end)

client:run('Bot ' .. token.getToken( 1 ))