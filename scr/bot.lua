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

-- MISC --

-- FISH REACT SOMEGUY --

client:on("messageCreate", function( message )
	
	if message.author.id == "565367805160062996" then
		
		message:addReaction("")
		
	end
	
end)

client:on("ready", function()
	
	--[[local started = srcds:start( "sandbox" )
	if started then
		srcds:promptUserInputP2pId()
	end]]
	
	benbebase.sendPrevError()
	
end)

client:run('Bot ' .. token.getToken( 1 ))