require("./lua/benbase")

local token, srcds = require("./lua/token"), require("./lua/source-dedicated-server")( "C:/dedicatedserver/garrysmod/" )

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

local ytdlp = require("./lua/api/ytdlp")()

ytdlp:setMaxThreading( 10 )

local formatOptions = {default = "webm", webm = "webm", mp4 = "mp4", mp3 = "mp4"}

local inQueue = {}

local c = commands:new( "download", function( message, args )
	
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
	
		local format, quality, url = args[2] and args[1], args[3] and args[2], args[3] or args[2] or args[1]
		format, quality = formatOptions[format or "default"], quality or "bv[filesize<5M]*+ba/b[filesize<7M]*/w"
		
		local invalidStart, invalidEnd = quality:find("[^%w%*%[%]%%<%>%=%d%%/%+]")
		
		if invalidStart then inQueue[message.author.id] = nil reply:setContent( "invalid quality string: " .. invalidStart .. " - " .. invalidEnd ) return end
		if not format then inQueue[message.author.id] = nil reply:setContent( "format must be 'default', 'filesizefix', 'best', 'worst', 'ytbest', or 'ytworst'" ) return end
		
		local success, result = ytdlp:queue( {"-f", quality, "--recode-video", format, url}, function( stage )
			
			reply:setContent( stage )
			
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
		
		message:reply("your video has been queued (in place " .. place .. ")")
		
		if not success then inQueue[message.author.id] = nil reply:setContent( result ) end
		
	end
	
end )
c:setHelp( "[<format> <quality>] <url>", "download a video from a variety of sites, for a list of supported sites see https://ytdl-org.github.io/youtube-dl/supportedsites.html" )

local c = commands:new( "gmod", function( message, args )
	
	message:reply(srcds:sbpLink())
	
end )
c:setHelp( "[<format> <quality>] <url>", "" )

-- MISC --

-- FISH REACT SOMEGUY --

client:on("messageCreate", function( message )
	
	if message.author.id == "565367805160062996" then
		
		message:addReaction("🐟")
		
	end
	
end)

client:on("ready", function()
	
	local started = srcds:start( "sandbox" )
	if started then
		srcds:promptUserInputP2pId()
	end
	
	benbebase.sendPrevError()
	
end)

client:run('Bot ' .. token.getToken( 1 ))
