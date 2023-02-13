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

command.new("help", function( message, _, arg )
	local target, targetName = command.get(arg or "")
	if target then 
		proxout(message.channel:send({
			embed = {
				title = "!m " .. targetName .. " " .. target.stx,
				description = target.desc
			}
		}))
		return
	end
	local content = {}
	for _,v in ipairs(command.get()) do
		if not v.stx:match("^%s?$") then
			v.stx = v.stx .. " "
		end
		table.insert(content, {name = "!m " .. v.name .. " " .. v.stx, value = v.desc, inline = true})
	end
	proxout(message.channel:send({
		embed = {
			--title = "",
			fields = content,
			--description = "",
			--timestamp = discordia.Date():toISO('T', 'Z')
		},
		refrence = {message = message, mention = false}
	}))
end, nil, "shows a list of commands", true, {"manageWebhooks"})

appdata.init({{"maw.ini"},{"maw.blk"},{"media/"}})

command.new("blacklist", function( message, args )
	if args[1] == "read" then
		message:reply(appdata.read("maw.blk"):gsub("\n", ", "))
	elseif args[1] == "add" then
		appdata.append("maw.blk", "\n" .. args[2])
	elseif args[1] == "remove" then
		
	elseif args[1] == "set" then
		
	end
end, "<mode> <term>", "mr electic send this man to the penis explosion chamber", false, {"manageWebhooks"})

command.new("icon", function( message )
	local attachment = message.attachment
	if attachment.content_type:match("^image/") then
		local _, file_content = http.request("GET", attachment.url)
		appdata.write("media/" .. attachment.filename, file_content)
		client:setAvatar(appdata.directory() .. "media/" .. attachment.filename)
		appdata.delete("media/" .. attachment.filename)
		message:reply("successfully set icon")
	else
		message:reply("USE AN IMAGE YOU ABSOLUTE MONGALOID")
	end
end, nil, "mr electric change this man's icon to whatever the fork", false, {"manageWebhooks"})

config.verify()

command.new("config", function( message, _, args )
	local section, key, value = args:match("([^%s]+)%s*([^%s]+)%s*(.-)$")
	if not section then
		message.author:send("```ini\n" .. appdata.read("maw.ini") .. "\n```")
	else
		if value then
			if section == "static" then message.channel:send("section static cannot be modified by non-operators") return end
			if not _config[section] then message.channel:send("no such section: " .. section) return end
			if _config[section][key] == nil then message.channel:send("no such key: " .. key) return end
			local old_value = _config[section][key]
			if value == "true" then
				value = true
			elseif value == "false" then
				value = false
			elseif value:match("^%d+$") then
				value = tonumber(value)
			elseif value:match("^s%d+$") then
				value = value:match("^s(%d+)$")
			end
			_config[section][key] = value
			if (section == "users") and (key == "msg_target") then
				client:getChannel(_config.channels.maurice_rw):send({embed = {description = "RECIPIENT SET TO " .. client:getUser(_config.users.msg_target).name:upper()}})
			end
			config.setKey(section, key, value)
			message.channel:send("set config " .. key .. " from " .. type(old_value) .. " " .. tostring(old_value) .. " to " .. tostring(value))
		else
			if not _config[key] then message.channel:send("no such key: " .. key) return end
			local old_value = _config[section]
			_config[section] = key
			config.setKey(nil, section, key)
			message.channel:send("set config " .. section .. " from " .. type(old_value) .. " " .. old_value .. " to " .. key)
		end
		_config = config.get()
	end
end, "<section> <key> <value>", "edit benbebot config", false, {"manageWebhooks"})

command.new("nerd", function(message, _, stuff)
	local target = stuff
	if message.referencedMessage then target = message.referencedMessage.cleanContent end
	message.channel:broadcastTyping()
	appdata.write("media/content.txt", message.referencedMessage.content)
	local file = media.overlayTextImage("resource/image/nerd.jpg", target, {
		"-fill", "black",
		"-pointsize", "48", 
		"-size", "680x", 
		"-gravity", "North", 
		"caption:@" .. appdata.directory() .. "media/content.txt",
		"resource/image/nerd.jpg",
		"-append"
	})
	message:reply({file = file})
	os.remove(file)
end, nil, "nerd!" )

local cooldown = 0

client:on('messageCreate', function(message)
	if ((message.author.id == _config.users.maurice) or (message.channel.id == _config.channels.test_channel)) and message.embed then
		if message.embed.type == "gifv" then
			for l in appdata.lines("maw.blk") do
				if message.embed.url:lower():match(l:gsub("%-", "%%%-")) then
					message:delete()
					if cooldown <= 0 then
						message:reply(":middle_finger:")
						cooldown = _config.misc.wave_cooldown
					end
					break
				end
			end
		end
	end
end)

client:on('messageCreate', function(message)
	if message.author.id == _config.users.msg_target and message.channel.type == 1 then
		client:getChannel(_config.channels.maurice_rw):send(message.cleanContent)
	elseif message.channel.id == _config.channels.maurice_rw and not message.author.bot then
		local success, err = client:getUser(_config.users.msg_target):getPrivateChannel():send(message.cleanContent)
		if not success then
			message:delete()
			client:getChannel(_config.channels.maurice_rw):setTopic(err)
		else
			timer.sleep(1000)
			client:getChannel(_config.channels.maurice_rw):setTopic()
		end
	end
end)

client:on('messageCreate', function(message)
	if message.channel.type == 1 then
		local message = message.content
		if message.file and message == "" then
			message = "<file>"
		end
		client:getChannel(_config.channels.dm_output):send(message.author.name .. ": " .. message.content)
	end
end)

local c = discordia.Clock()

c:on("sec", function()
	cooldown = cooldown - 1
end)

client:on('ready', function()
	c:start()
end) 

client:run('Bot ' .. tokens.getToken( 16 ))