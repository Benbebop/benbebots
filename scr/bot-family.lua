require("./lua/benbase")

local discordia, token, youtube, appdata, http, soap2day, statistics = require('discordia'), require("./lua/token"), require("./lua/api/youtube"), require("./lua/appdata"), require("coro-http"), require("./lua/api/soap2day"), require("./lua/statistics")

math.randomseed( os.time() )

appdata.init({{"familyguyvids/"},{"familyguyvids/index.db", ""}})

local videoarchive = require("./lua/videoarchive")( appdata.path( "familyguyvids/" ) )

videoarchive.videoMaxSize = "3M"

local truncate = require("./lua/string").truncate

local client = discordia.Client({cacheAllMembers = true})

benbebase.initialise( client, "familyguy" )
local output = benbebase.output
local commands = require("./lua/command")()

local clock = discordia.Clock()

client:on('messageCreate', function(message)
	if message.channel.type == 1 then
		if message.author.id ~= client.user.id then
			local cat = client:getChannel("1031005877802651698")
			local sudodm = cat.textChannels:find(function(channel) return channel.topic == message.author.id end)
			if not sudodm then
			
				sudodm = cat:createTextChannel(message.author.name)
				sudodm:setTopic(message.author.id)
			
			end
			if sudodm.name ~= message.author.name then sudodm:setName(message.author.name) end
			sudodm:send({
				content = message.cleanContent,
				refrence = {message = message.referencedMessage, mention = false}
			})
			if message.attachments then
				for _,v in ipairs(message.attachments) do
					sudodm:send(v)
				end
			end
			sudodm:moveUp(sudodm.position)
		else
			
		end
	elseif (message.guild or {}).id == "1031002500859441213" then
		
		local channel = message.channel or {}
		
		if (channel.parent or {}).id == "1031005877802651698" then
			
			local user = client:getUser(channel.topic)
			
			if not user then return end
			
			user:sendf(message.cleanContent)
			
		end
		
	end
end)

function extractId( url )
	url = http.parseUrl( url )
	if not (url.hostname == "www.youtube.com" or url.hostname == "youtube.com" or url.hostname == "youtu.be") then return false, "that isnt youtube dumbass" end
	if url.path:sub(1,6) == "/watch" then
		for i,v in url.path:sub(8,-1):gmatch("(.-)=(.-)&?$") do
			if i == "v" then return v end
		end
		return false, "doesnt even link to a video"
	elseif url.path:sub(1,7) == "/shorts" then
		local id = url.path:sub(9,-1):match("^[^%?]+")
		return id
	elseif url.hostname == "youtu.be" then
		return url.path:sub(2,-1)
	else
		return false, "fucked up url"
	end
end

function verifyVideo( id )
	local h = http.request("HEAD", "https://www.youtube.com/oembed?url=http%3A//www.youtube.com/watch%3Fv%3D" .. id .."&format=json")
	return h.code == 200
end

local send_delay_time = math.huge

local sendDelay = 0

local sentVideos = statistics( 24, 4, "L" )

local function sendRandomVideo( user )
	
	local vindex = math.random(1, videoarchive.entries)
		
	local success, meta, content = videoarchive:getVideo(vindex)
		
	if not success then return end
	
	local debugMessage = client:getChannel("1031015533501497394"):send("sent " .. (user.name or "nul") .. " video https://www.youtube.com/watch?v=" .. meta.id .. " (" .. vindex .. "." .. meta.ext .. ")")
		
	local channel = user:getPrivateChannel()
		
	if not channel then return end
		
	local success, err = channel:send({
		file = {videoarchive:uniqueId() .. "." .. meta.ext, content}
	})
	
	if not success then
		
		debugMessage:setContent("couldnt send message to " .. (user.name or "nul") .. " (" .. err .. ")")
		
	else
		
		sentVideos:increase( 1 )
		
	end
	
end

clock:on("sec", function()

	sendDelay = sendDelay + 1
	
	if sendDelay >= send_delay_time then
		
		sendDelay = 0
		
		local user

		repeat user = client.users:random() until not user.bot
		
		sendRandomVideo( user )
		
	end
	
end)

local whitelist = {"823215010461384735", "459880024187600937"}

local length_of_vid = 11

client:on('messageCreate', function(message)
	if (message.guild or {}).id == "1031002500859441213" then
		if message.content:lower():match("^addvideo") then
			
			local reply = message:reply("adding video to database")

			local id, err = extractId(message.content:match("^addvideo%s*([^%s]+)"))
			
			if not id then reply:setContent(err) return end
			
			if #id ~= length_of_vid then reply:setContent("video id is fucked?!??!?! (" .. id .. ")") return end
			
			if not verifyVideo( id ) then reply:setContent("video does not exist on youtube!>?!>!") return end
			
			local found = false
			
			local success, result = videoarchive:addVideoSync( id, function(_, stage)
				
				reply:setContent("downloading the video (" .. stage .. ")")
				
			end)
			
			if not success then 
				reply:setContent(result)
			else
				reply:setContent("finished downloading")
				local success, meta, content = videoarchive:getVideo(result)
				if success then
					message:reply({
						file = {result .. "." .. meta.ext, content}
					})
				end
			end
			
		elseif message.content:lower():match("^removevideo") then
			
			local reply = message:reply("fucking demolishing your video dude")

			local id, err = extractId(message.content:match("^removevideo%s*([^%s]+)"))
			
			if not id then reply:setContent(err) return end
			
			if #id ~= length_of_vid then reply:setContent("video id is fucked?!??!?! (" .. id .. ")") return end
			
			local index = videoarchive:getIndex( id )
			
			if not index then reply:setContent("video not found") return end
			
			local success, err = videoarchive:removeVideo( index )
			
			if not success then
				reply:setContent(err)
			else
				reply:setContent("fucking destroyed that vid")
			end
			
		elseif message.content:lower():match("^list") then
			
			message:reply(videoarchive.entries)
			
		elseif message.content:lower():match("^getvideo") then
			
			sendRandomVideo( message.author )
			
		elseif message.content:lower():match("^forcesend") then
			
			sendDelay = send_delay_time
			
		elseif message.content:lower():match("^timetonextsend") then
			
			message:reply(send_delay_time - sendDelay .. " seconds")
			
		elseif message.content:lower():match("^invite") then
			
			message:reply("https://discord.com/api/oauth2/authorize?client_id=1021287182641668096&permissions=0&scope=bot")
			
		end
	end
end)

local canReacts = {["860934345677864961"] = {"549112267913035787", "https?://"}}

--[[client:on('messageCreate', function(message)
	local canReact = canReacts[message.id]
	if canReact and canReact[1] == message.author.id and message.content:match(canReact[2]) then
		message:addReaction("\uD83E\uDD6B")
	end
end )]]

local send_period = 172800 * 4

client:on("ready", function()
	
	clock:start()
	
	send_delay_time = math.floor( send_period / #client.users )
	
	benbebase.sendPrevError("-family")
	
end)

client:on("memberJoin", function()
	
	send_delay_time = math.floor( 172800 / #client.users )
	
end)

client:run('Bot ' .. token.getToken( 20 ))