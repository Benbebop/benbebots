require("./lua/benbase")

local discordia, tokens, appdata, fs = require('discordia'), require("./lua/token"), require("./lua/appdata"), require("fs")

local commands = require("./lua/command")( "%-%-" )

local client = discordia.Client({cacheAllMembers = true})

local channel = "822165179692220479"
local guild = "822165179692220476"

function split(lenth, str)
	length = tonumber(length or 1999)
	local cursor = 0
	repeat
		cursor = cursor + length + 1
		repeat until client:getChannel(channel):send(str:sub(cursor - length, cursor))
	until #str:sub(cursor - length, cursor) < length
end

appdata.init({{"takeover_backups/"},{"send.log"}})

commands:new("channel", function( _, args )
	channel = args[1]
end)

commands:new("ban", function( arg )
	arg = arg.c
	client:getGuild(guild):getMember(arg):ban("FUCK YOU")
end)

commands:new("kick", function( arg )
	arg = arg.c
	client:getGuild(guild):getMember(arg):kick("FUCK YOU")
end)

commands:new("spam", function( _, _, arg )
	local duration, message = arg:match("(%d+)%s*(.-)$")
	for i=1,tonumber(duration) do
		repeat until client:getChannel(channel):send(message:gsub("%%i", i))
	end
end)

commands:new("split", function( arg )
	arg = arg.c
	split(arg:match("^(%d+)%s*(.-)$"))
end)

commands:new("say", function( arg )
	arg = arg.c
	local f = io.open("say.txt", "rb")
	local s = f:read("*a")
	f:close()
	split(arg:match("^(%d+)%s*$"), s)
end)

commands:new("run", function( arg )
	arg = arg.c
	local f = assert(loadstring(arg))
	setfenv(f, {discordia = discordia, client = client, json = require("json"), print = p, emoji = emoji, pcall = pcall})
	p(f())
end)

commands:new("dm", function( _, _, arg )
	channel = client:getUser(arg:match("(%d+)")):getPrivateChannel().id
end)

commands:new("takeover", function( arg )
	arg = arg.c
	local i = 0
	repeat i = i + 1 until not appdata.exists("takeover_backups/takeover_" .. i .. ".dat")
	local STX, ETX, GS, RS, US = string.char(2), string.char(3), string.char(29), string.char(30), string.char(31)
	local f = appdata.get("takeover_backups/takeover_" .. i .. ".dat", "wb")
	local g = client:getGuild(guild)
	f:write("REWARD", STX, arg .. " Takeover Survivors", ETX, GS, "REPLACE", STX, arg, ETX, GS, "GUILD", STX, g.name, US, g.description or "", ETX, GS, "CATAGORIES", STX)
	g.categories:forEach(function(c)
		f:write(c.id, US, c.name, RS)
	end)
	f:close() f = appdata.get("takeover_backups/takeover_" .. i .. ".dat", "ab")
	f:write(ETX, GS, "TEXTCHANNELS", STX)
	g.textChannels:forEach(function(t)
		f:write(t.id, US, t.name, US, t.topic or "", RS)
	end)
	f:close() f = appdata.get("takeover_backups/takeover_" .. i .. ".dat", "ab")
	f:write(ETX, GS, "VOICECHANNELS", STX)
	g.voiceChannels:forEach(function(v)
		f:write(v.id, US, v.name, RS)
	end)
	f:close() f = appdata.get("takeover_backups/takeover_" .. i .. ".dat", "ab")
	f:write(ETX, GS, "ROLES", STX)
	g.roles:forEach(function(r)
		f:write(r.id, US, r.name, RS)
	end)
	f:close() f = appdata.get("takeover_backups/takeover_" .. i .. ".dat", "ab")
	f:write(ETX, GS, "MEMBERS", STX)
	g.members:forEach(function(m)
		f:write(m.id, US, m.name, RS)
	end)
	f:write(ETX)
	f:close()
	local confirm = appdata.read("takeover_backups/takeover_" .. i .. ".dat")
	local function set(c)
		if confirm:match(c.id) then
			c:setName(arg)
		else
			print("could not locate " .. c.name .. " in backup file, skipping")
		end
	end
	g.categories:forEach(set)
	g.textChannels:forEach(set)
	g.voiceChannels:forEach(set)
	g.roles:forEach(set)
	g.members:forEach(function(c)
		if confirm:match(c.id) then
			c:setNickname(arg)
		else
			print("could not locate " .. c.name .. " in backup file, skipping")
		end
	end)
end)

commands:new("undotakeover", function( arg )
	arg = arg.c
	local i = 0
	repeat i = i + 1 until not appdata.exists("takeover_backups/takeover_" .. i .. ".dat")
	local STX, ETX, GS, RS, US = string.char(2), string.char(3), string.char(29), string.char(30), string.char(31)
	local content = appdata.read("takeover_backups/takeover_" .. i - 1 .. ".dat")
	local textmatch = STX .. "([^" .. ETX .. "]+)" .. ETX
	local g = client:getGuild(guild)
	local name, description = content:match("GUILD" .. textmatch):match("^(.-)" .. US .. "(.-)$")
	g:setName(name) --g:setDescription(description)
	for record in content:match("CATAGORIES" .. textmatch):gmatch("[^" .. RS .. "]+") do
		local unit = record:gmatch("([^" .. US .. "]+)")
		g:getChannel(unit()):setName(unit())
	end
	for record in content:match("TEXTCHANNELS" .. textmatch):gmatch("[^" .. RS .. "]+") do
		local unit = record:gmatch("([^" .. US .. "]+)")
		local channel = g:getChannel(unit())
		channel:setName(unit())
		channel:setTopic(unit() or "")
	end
	for record in content:match("VOICECHANNELS" .. textmatch):gmatch("[^" .. RS .. "]+") do
		local unit = record:gmatch("([^" .. US .. "]+)")
		g:getChannel(unit()):setName(unit())
	end
	for record in content:match("ROLES" .. textmatch):gmatch("[^" .. RS .. "]+") do
		local unit = record:gmatch("([^" .. US .. "]+)")
		g:getRole(unit()):setName(unit())
	end
	local reward = g:createRole(content:match("REWARD" .. textmatch))
	reward:disableAllPermissions()
	reward:unhoist()
	for record in content:match("MEMBERS" .. textmatch):gmatch("[^" .. RS .. "]+") do
		local unit = record:gmatch("([^" .. US .. "]+)")
		local member = g:getMember(unit())
		if member.name:lower() == content:match("REPLACE" .. textmatch):lower() then
			member:setNickname(unit())
			member:addRole(reward.id)
		end
	end
end)

commands:new("dm", function( arg )
	arg = arg.c
	local message = client:getChannel(channel):getMessage(arg)
	repeat until not message:addReaction(emoji.random())
end)

commands:new("srt", function( arg )
	arg = arg.c
	local timer, uv = require("timer"), require("uv")
	local start = uv.gettimeofday()
	local c = client:getChannel(channel)
	for _,tstart,_,content in subtitle.itterator(arg) do
		repeat until c:send(subtitle.format(content))
		local s, us = uv.gettimeofday()
		local t = s + (us / 1e6)
		print(math.max(0, tstart - (t - start)) * 10)
		timer.sleep(math.max(0, tstart - (t - start)) * 10)
	end
end)

commands:new("srtunsync", function( arg )
	arg = arg.c
	local c = client:getChannel(channel)
	for _,_,_,content in subtitle.itterator(arg) do
		repeat until c:send(content)
	end
end)

commands:new("images", function( arg )
	arg = arg.c
	local scan = fs.scandirSync(arg)
	repeat
		local tbl, f = {}, nil
		for i=1,10 do
			local f = scan()
			if not f then break end
			table.insert(tbl, f)
		end
	until not f
end)

client:on('ready', function()
	io.write("Logged in as ", client.user.username, "\n")
	repeat
		local bollox = io.read():gsub("[^\\]\\n", "\n")
		appdata.append("send.log", "\n" .. bollox)
		if bollox:match("^%s*%-%-") then
			commands:runString( bollox )
		else
			client:getChannel(channel):send(bollox)
		end
	until false
end) 

client:run('Bot ' .. tokens.getToken(tonumber(args[2]) or 1))