local discordia, appdata, tokens, timer, config, fs = require('discordia'), require("./lua/appdata"), require("./lua/token"), require("timer"), require("./lua/config"), require("fs")

local client = discordia.Client()
local clock = discordia.Clock()
local output = require("./lua/output")(client)

local myguild = "822165179692220476"

function proxout( success, result )
	if not success then
		o:output( result, "err" )
	else
		return success
	end
end

function sendPrevError()
	local f = io.open("errorhandle/error-a.log", "r")
	if f then
		local content = f:read("*a")
		if content == "" then return end
		local err, trace = content:match("^(.-)\nstack traceback:\n(.-)$")
		output:o( err, "err", trace )
		f:close()
		os.remove("errorhandle/error-a.log")
	end
end

client:on('ready', function()
	sendPrevError()
	clock:start()
end) 

local random_sounds = fs.readdirSync('resource/sound/random')
random_sounds.n = #random_sounds

local boneconnection = nil

clock:on("sec", function()
	local _config = config.get()
	if boneconnection and math.random(1,10000) <= _config.audioplayer.frequency * 100 then
		client:getGuild(myguild).me:undeafen()
		local sound = _config.audioplayer.sound
		if sound == "random" then
			sound = random_sounds[math.random(random_sounds.n)]
		end
		local file = io.open('resource/sound/random/' .. sound, 'rb') or io.open('resource/sound/random/' .. random_sounds[math.random(random_sounds.n)], 'rb')
		boneconnection:playPCM(file:read("*a"))
		file:close()
	end
end)

client:on('voiceChannelJoin', function(m, c)
	if c.id == "972359183510958170" and not boneconnection then
		timer.sleep(500)
		boneconnection = client:getChannel("972359183510958170"):join()
	end
end) 

client:on('voiceChannelLeave', function(m, c)
	if c.id == "972359183510958170" and c.connectedMembers:count() <= 1 and boneconnection then
		boneconnection:close()
		boneconnection = nil
	end
end) 

client:run('Bot ' .. tokens.getToken( 1 ))