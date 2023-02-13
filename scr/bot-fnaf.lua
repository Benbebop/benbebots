local discordia, command, appdata, config, tokens, str_ext, http, media, timer = require('discordia'), require("./lua/command"), require("./lua/appdata"), require("./lua/config"), require("./lua/token"), require("./lua/string"), require("coro-http"), require("./lua/media"), require("timer")

local client = discordia.Client()

local truncate = str_ext.truncate

local _config = config.get()

function output( str, mode, overwrite_trace )
	if not str then return end
	print( str )
	if mode == "silent" then return end
	str = truncate(str, "desc", true)
	mode = mode or "null"
	local foot = nil
	if mode == "err" then foot = {text = debug.traceback()} end
	if overwrite_trace then foot = {text = overwrite_trace} end
	foot = truncate(foot, "text", true)
	mode = outputModes[mode] or outputModes.null
	str = str:gsub("%d+%.%d+%.%d+%.%d+", "\\*\\*\\*.\\*\\*\\*.\\*\\*\\*.\\*\\*")
	client:getChannel("998495920343765012"):send({
		embed = {
			description = str,
			color = discordia.Color.fromRGB(mode[1], mode[2], mode[3]).value,
			footer = foot,
			timestamp = discordia.Date():toISO('T', 'Z')
		}
	})
end

function proxout( success, result )
	if not success then
		output( result, "err" )
	end
end

client:on('messageCreate', function(message)
	local str = message.content
	if (str:lower():match("^!m") or str:lower():match("^!maw")) then
		local content = str:gsub("^![mM]%s*", ""):gsub("^![mM][aA][wW]%s*", "")
		if content then
			local success, result = command.run(content, message)
			if not success then
				output(result)
			end
		 end
	end
end)

command.new("icon", function( message )
	local attachment = message.attachment
	if attachment.content_type:match("^image/") then
		local _, file_content = http.request("GET", attachment.url)
		appdata.write("media/" .. attachment.filename, file_content)
		client:setAvatar(appdata.directory() .. "media/" .. attachment.filename)
		appdata.delete("media/" .. attachment.filename)
		message:reply("successfully set icon")
	else
		message:reply("use an image :pleading_face:")
	end
end, nil, "mr electric change this man's icon to whatever the fork", false, {"manageWebhooks"})

local reggieRole, c1, c2, colorToggle = "1002025402870542396", discordia.Color.fromRGB(110, 247, 218).value, discordia.Color.fromRGB(255, 123, 163).value, false

function toggleColor()
	colorToggle = not colorToggle
	client:getRole(reggieRole):setColor(colorToggle and c1 or c2)
end

command.new("toggle", toggleColor, nil, nil)

local c = discordia.Clock()

c:on("hour", toggleColor)

client:on('ready', function()
	c:start()
	toggleColor()
end)

client:run('Bot ' .. tokens.getToken( 17 ))