local discordia, http, json, thread, lwz, roleGiver, appdata, holiday, tokens, str_ext, server_info, coro_spawn, config, yt_downloader, media, uv, fs = require('discordia'), require("coro-http"), require("json"), require("coro-thread-work"), require("./lua/lualwz"), require("./lua/roleGiver"), require("./lua/appdata"), require("./lua/holiday"), require("./lua/token"), require("./lua/string"), require("./lua/server"), require("coro-spawn"), require("./lua/config"), require("./lua/youtube-dl"), require("./lua/media"), require("uv"), require("fs")

local f = io.open("tables/global.ini.default")
appdata.init({{"permaroles.dat"},{"company.json", "{}"},{"employed.json","{}"},{"global.ini",f:read("*a")}})
f:close()

config.verify()

local _config = config.get()

local client = discordia.Client()
local dClock = discordia.Clock()
local discordiaPackage = require('discordia\\package')

local initFile = {}
local allRoles = {}
local helpText = require("./tables/helptext")

local truncate = str_ext.truncate

local outputModes = {null = {255, 255, 255}, info = {0, 0, 255}, err = {255, 0, 0}, mod = {255, 100, 0}, warn = {255, 255, 0}, http = {113, 113, 255}}

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
	client:getChannel("959468256664621106"):send({
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

function setHoliday( holiday )
	if not _config.misc.suspend_holiday then
	client:setAvatar("images/icons/" .. holiday.avatar)
	client:setUsername(holiday.name)
	local member = client:getGuild(_config.static.myGuild):getMember(client.user.id)
	member:setNickname(holiday.name)
	if holiday.game == "none" or holiday.game == "" then
		client:setGame()
	else
		client:setGame(holiday.game)
	end
	if not holiday.text then
		member:removeRole(_config.roles.day_identifier)
		client:getRole(_config.roles.day_identifier):setName("benbebot day identifier")
	else
		member:addRole(_config.roles.day_identifier)
		client:getRole(_config.roles.day_identifier):setName(holiday.text)
	end
	--output("today is " .. holiday.text)
	else
		client:setAvatar("images/icons/default.jpg")
		client:setUsername("benbebot")
		local member = client:getGuild(_config.static.myGuild):getMember(client.user.id)
		member:setNickname(holiday.name)
		member:removeRole(_config.roles.day_identifier)
		client:getRole(_config.roles.day_identifier):setName("benbebot day identifier")
		client:setGame()
	end
end

function sendPrevError()
	local f = appdata.get("errorhandle/error.log", "r")
	if f then
		local content = f:read("*a")
		if content == "" then return end
		local err, trace = content:match("^(.-)\nstack traceback:\n(.-)$")
		output( err, "err", trace )
		f:close()
	end
end

local githubAPI = require("./lua/api/github")

client:on('ready', function()
	dClock:start()
	setHoliday( holiday() )
	sendPrevError()
	io.write("Logged in as ", client.user.username, "\n")
end) 

-- API RESET --
local apiTracker = require("./lua/api/tracker")

dClock:on("hour", function()
	output("clearing api tracker", "silent")
	apiTracker.clear()
end)

-- Commands --
local command, server, youtube, websters = require("./lua/command"), require("./lua/computer"), require("./lua/api/youtube"), require("./lua/api/websters")

client:on('messageCreate', function(message)
	local content = command.parse(message.content)
	if content then
		local success, result = command.run(content, message)
		if not success then
			output(result)
		end
	end
end)

command.new("help", function( message, _, arg )
	local target, targetName = command.get(arg or "")
	if target then 
		proxout(message.channel:send({
			embed = {
				title = "bbb " .. targetName .. " " .. target.stx,
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
		table.insert(content, {name = "bbb " .. v.name .. " " .. v.stx, value = v.desc, inline = true})
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
end, nil, "shows a list of commands", true)

command.new("status", function( message ) -- RETURNS STATUS OF SERVER --
	if (message.channel.id == "831564245934145599") or (message.channel.id == "832289651074138123") or true then
		message.channel:broadcastTyping()
		local dVersion, version, status, cpu, memory, networkrecieve, networktransfer, networksignal, duration = server.getStatus()
		proxout(message.channel:send("benbebot is online | discordia " .. dVersion .. " | " .. version .. "\nServer Status: " .. status .. "\ncpu: " .. cpu .. "%, memory: " .. memory .. " GB\nrecieve: " .. networkrecieve .. ", transfer: " .. networktransfer .. ", signal: " .. networksignal .. "%\nuptime: " .. math.floor( os.clock() / 60 / 6 ) / 100 .. "h"))
		output("status requested by " .. message.author.name .. " (" .. duration .. "s)", "info")
	end
end, nil, "get server status")

command.new("config", function( message, _, args )
	local section, key, value = args:match("([^%s]+)%s*([^%s]+)%s*(.-)$")
	if not section then
		message.author:send("```ini\n" .. appdata.read("global.ini") .. "\n```")
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

command.new("random", function( message, args ) -- MAKES A RANDOM NUMBER --
	local initial, final = args[1], args[2]
	if initial and final then
		initial, final = tonumber(initial), tonumber(final)
		if initial > final then initial, final = final, initial end
		proxout(message.channel:send(tostring(math.random(initial, final))))
	end
end, "<lower limit> <upper limit>", "generates a random number")

command.new("define", function( message, args ) -- DEFINES A WORD --
	local success, content, found, title = websters.getDefinition( args[1] )
	local result = websters.getDefinition( args[1] )
	if result.status ~= "OK" then output(result.data, "err") return end
	local success, content, found, title = true, result.data[1], result.data[2], result.data[3]
	if content then
		local desc = nil
		if not found then desc = "no definition exists for your word, here are some suggestions" end
		proxout(message.channel:send({
			embed = {
				title = title,
				fields = content,
				description = desc,
				timestamp = discordia.Date():toISO('T', 'Z')
				},
			refrence = {message = message, mention = false}
		}))
		proxout(message.channel:send(result))
	elseif success then
		proxout(message.channel:send("couldnt find definition for " .. todefine))
	else
		-- do nothing for now
	end
end, "<word>", "uses the webster's dictionary api to define words")

command.new("calc", function( message, _, argument ) -- RENDER --
	if #argument < math.huge then
		local success, result = pcall(load("return " .. argument:gsub("\n", " "), nil, "t", math))
		if success then
			if argument:match("^%s*9%s*%+%s*10%s*$") and result == 19 then
				result = 21
			end
			if type(result) == "number" then
				proxout(message.channel:send( tostring( result ) ))
			end
		end
	end
end, "<lua>", "calculates a value based on a lua string")

command.new("vote", function( message ) -- VOTE --
	if message.channel.id == _config.static.c_announcement then
		message:addReaction("👍")
		message:addReaction("👎")
	end
end, nil, "calls vote in announcemnt", true)

command.new("s_announce", function( message ) -- SCHOOL ANNOUNCMENT --
	message:delete()
	local announcement = youtube.getSchoolAnnouncements()
	if announcement.status ~= "OK" then output(announcement.data) return end
	local mString = client:getRole(_config.roles.school_announcment).mentionString
	for _,v in ipairs(announcement.data) do
		client:getGuild(_config.static.myGuild):getChannel(_config.static.c_announcement):send(mString .. "\nhttps://www.youtube.com/watch?v=" .. v)
	end
end, nil, nil, true)

command.new("pp", function( message ) -- PENID --
	local target = message.mentionedUsers.first or message.author
	math.randomseed(target.id)
	local rand = math.random(-1000, 1000) / 750
	local sign = 0
	if rand ~= 0 then
		sign = rand / math.abs(rand)
	end
	local r = math.floor( rand ^ 2 * sign * 1.5 + 5 )
	if target.id == _config.users.ben then
		r = 8
	end
	proxout(message.channel:send({
		embed = {
			fields = {
				{
					name = target.name .. "'s pp", value = "8" .. string.rep("=", r) .. "D", inline = true}
				},
				color = discordia.Color.fromRGB((9 - math.min( r, 9 )) / 9 * 255, math.min( r, 9 ) / 9 * 255, 0).value
			},
		refrence = {message = message, mention = false}
	}))
end, "<target>", "imperical measurement of a man's penis")

command.new("ryt", function( message ) -- PENID --
	message.channel:broadcastTyping()
	local result = youtube.randomVideo()
	if result.status ~= "OK" then output(result.data) return end
	proxout(message.channel:send("https://www.youtube.com/watch?v=" .. address))
end, nil, "uses https://petittube.com to find a random unknown video")

command.new("fuckdankmemer", function( message ) -- PENID --
	local dm = client:getGuild(_config.static.myGuild):getMember(_config.users.dankmemer)
	if dm:hasRole(_config.roles.dankmemer_mute) then
		dm:removeRole(_config.roles.dankmemer_mute)
	else
		dm:addRole(_config.roles.dankmemer_mute)
	end
	message:delete()
end, nil, "dank memer cant send messages anymore :vballs:", true)

command.new("github", function( message ) -- PENID --
	proxout(message.channel:send("https://github.com/Benbebop/Benbebot"))
end, nil, "sends the benbebot github repository", true)

initFile = appdata.get("employed.json", "r")
local forceEmployed = json.parse(initFile:read("*a"))
initFile:close()

command.new("forceemploy", function( message ) -- PENID --
	if message.member:hasRole(_config.roles.company_CEO) and message.mentionedUsers.first then
		local target = client:getGuild(_config.static.myGuild):getMember(message.mentionedUsers.first.id)
		local employed = false
		for i,v in ipairs( forceEmployed ) do
			if target.id == v then
				employed = i
				break
			end
		end
		if employed then
			forceEmployed[employed] = nil
			target:removeRole(_config.roles.company_employee)
			proxout(message.channel:send("succesfully fired"))
		else
			table.insert(forceEmployed, target.id)
			target:addRole(_config.roles.company_employee)
			proxout(message.channel:send("succesfully employed"))
		end
		initFile = appdata.get("employed.json", "w+")
		initFile:write(json.stringify(forceEmployed))
		initFile:close()
	else
		proxout(message.channel:send("you do not have permissions to use this command"))
	end
end, "<target>", "bypass autoemploy on target", true)

initFile = appdata.get("company.json", "r")
local company = json.parse(initFile:read("*a"))
initFile:close()

command.new("companyrebrand", function( message, _, argument ) -- PENID --
	if message.member:hasRole(_config.roles.company_CEO) or message.author.id == _config.users.ben then
		local gm = argument:gmatch("%b\"\"")
		local name, color, autoemploy, autofire = gm() or "", gm() or "", gm() or "", nil
		name, color, autoemploy, autofire = name:gsub("\"", ""), color:gsub("\"", ""), autoemploy:gsub("\"", ""), autofire == "true"
		local prevname, prevae = company.name, company.autoemploy
		if autoemploy:match("^%s*$") then 
			company.autoemploy = company.autoemploy
		else 
			company.autoemploy = autoemploy 
		end
		local g = client:getGuild(_config.static.myGuild)
		local ceo, employ = g:getRole(_config.roles.company_CEO), g:getRole(_config.roles.company_employee)
		if color:match("%d+%s+%d+%s+%d+") then 
			color = {color:match("(%d+)%s+(%d+)%s+(%d+)")}
			company.color = color
		else
			color = {ceo:getColor():toRGB()}
		end
		if not name:match("^%s*$") then 
			company.name = name 
		end
		local prevceo = ceo.name
		ceo:setName(company.name .. " CEO's")
		local prevemploy = employ.name
		employ:setName(company.name .. " Employees")
		local cCeo, cEmploy = ceo:getColor(), employ:getColor()
		local cDiff, cSet = cEmploy - cCeo, discordia.Color()
		cSet:setRed(tonumber( color[1] )) cSet:setGreen(tonumber( color[2] )) cSet:setBlue(tonumber( color[3] ))
		ceo:setColor(cSet)
		employ:setColor(cSet + cDiff)
		initFile = appdata.get("company.json", "w+")
		initFile:write(json.stringify(company))
		initFile:close()
		local e_inline = false
		proxout(message.channel:send({
			embed = {
				title = "Company Rebrand Results",
				fields = {
					{name = "Name", value = "\"" .. prevname .. "\" to \"" .. company.name .. "\"", inline = e_inline},
					{name = "Role Color", value = cCeo.r .. " " .. cCeo.g .. " " .. cCeo.b .. " to " .. cSet.r .. " " .. cSet.g .. " " .. cSet.b, inline = e_inline},
					{name = "Autoemploy String", value = "\"" .. prevae .. "\" to \"" .. company.autoemploy .. "\"", inline = e_inline},
					{name = "Ceo Role Name", value = "\"" .. prevceo .. "\" to \"" .. company.name .. " CEO's\"", inline = e_inline},
					{name = "Employee Role Name", value = "\"" .. prevemploy .. "\" to \"" .. company.name .. " Employees\"", inline = e_inline},
				},
				color = discordia.Color.fromRGB(cSet.r, cSet.g, cSet.b).value,
				description = "some changes take some time to take effect, please wait",
				timestamp = discordia.Date():toISO('T', 'Z')
				},
			refrence = {message = message, mention = false}
		}))
	else
		proxout(message.channel:send("you do not have permissions to use this command"))
	end
end, "", "", true)

local clash = require("./lua/api/clash")

local server_clan = "%23" .. _config.misc.coc_clan_id

command.new("clan", function( message )
	local clan = clash.getClanInfo( server_clan )
	if clan.status ~= "OK" then output(clan.status, "err") return end
	clan = clan.data
	proxout(message.channel:send {
		embed = {
			title = clan.name,
			fields = {
				{name = "Tag", value = clan.tag, inline = false},
				{name = "Required Trophies", value = clan.trophies, inline = true},
				{name = "Required Townhall Level", value = clan.townhallLevel, inline = false},
				{name = "Wins", value = clan.wins, inline = true},
				{name = "Ties", value = clan.ties, inline = true},
				{name = "Losses", value = clan.losses, inline = true},
				{name = "Members", value = clan.members, inline = false},
			},
			description = clan.description,
			image = {
				url = clan.image,
				height = 70,
				width = 70
			},
			color = discordia.Color.fromRGB(clan.r, clan.g, clan.b).value,
			timestamp = discordia.Date():toISO('T', 'Z')
		}
	})
end, "", "(clash of clans) get the servers clan")

command.new("war", function( message )
	local war = clash.getWarInfo( server_clan )
	if war.status ~= "OK" then output(war.status, "err") return end
	war = war.data
	if war then
	proxout(message.channel:send {
		embed = {
			title = war.c .. " VS " .. war.o,
			fields = {
				{name = war.c, value = war.cTag, inline = false},
				{name = "Destruction", value = war.cDest .. "%", inline = true},
				{name = "Attacks", value = war.cAttacks, inline = true},
				{name = "Stars", value = war.cStars, inline = true},
				{name = war.o, value = war.oTag, inline = false},
				{name = "Destruction", value = war.oDest .. "%", inline = true},
				{name = "Attacks", value = war.oAttacks, inline = true},
				{name = "Stars", value = war.oStars, inline = true},
			},
			-- description = "",
			-- image = {
				-- url = war.opponent.badgeUrls.small,
				-- height = 20,
				-- width = 20
			-- },
			color = discordia.Color.fromRGB(war.r, war.g, war.b).value,
			timestamp = war.stamp
		}
	})
	else
		proxout(message.channel:send("there is no clan war currently"))
	end
end, "", "(clash of clans) clan's war status")

command.new("war_announce", function( message, _, arg )
	message:delete()
	if message.channel.id == _config.static.c_announcement then
	local war = clash.getWarAnnounce( server_clan, client:getRole("954149526325833738"), arg )
	if war.status ~= "OK" then output(war.status, "err") return end
	war = war.data
	proxout(message.channel:send({
		content = war.content,
		embed = {
			title = war.c .. " is under attack",
			description = war.desc,
			fields = {
				{name = war.o, value = war.oTag or "err_nil", inline = false},
				{name = "Wins", value = war.oWins or "err_nil", inline = true},
				{name = "Ties", value = war.oTies or "err_nil", inline = true},
				{name = "Losses", value = war.oLosses or "err_nil", inline = true},
				{name = "Members", value = war.oMembers or "err_nil", inline = false},
			},
			-- description = "",
			-- image = {
				-- url = war.opponent.badgeUrls.small,
				-- height = 20,
				-- width = 20
			-- },
			color = war.color,
			timestamp = war.stamp
		}
	}))
	end
end, "<description>", "(clash of clans) announce war", true)

local cocLiveMessage = false

local function wl( message, _, arg )
	message:delete()
	if true then--message.channel.id == _config.static.c_announcement then
		cocLiveMessage = clash.liveWarMessage( message.channel:send({
			content = client:getRole("954149526325833738").mentionString,
			embed = clash.liveEmbedInit
		}), server_clan )
		if cocLiveMessage.status ~= "OK" then output(cocLiveMessage.status, "err") return end
		cocLiveMessage = cocLiveMessage.data
		cocLiveMessage:update()
		output("new war_live object created", "info")
	end
end

command.new("war_live", wl, "", "(clash of clans) sends message that will update as a war happens", true)

client:on('messageCreate', function(message)
	if message.author.id == _config.users.paul then
		if message.mentionedRoles:find(function(v) return v.id == "968908152093409310" end) then
			if not message.content:match("war") then return end
			message:delete()
			wl( client:getChannel("823397621887926272"):send("funny little message cause the way i set up the bot there has to be a message in the announcements channel for the war live object to work") )
		end
	end
end)

dClock:on("min", function()
	if cocLiveMessage and tonumber(os.date("%M")) % 15 == 0 then
		local info = cocLiveMessage:update()
		if info.status ~= "OK" then output(info.data, "err") return end
		if info.data == false then cocLiveMessage:delete() cocLiveMessage = nil output("war_live concluded", "info") return end
		output("war_live updated", "info")
	end
end)

local vdsg_catalogue = {}
for l in io.lines("./tables/vdsg.txt") do 
	local id, content = l:match("^(%d+)%s+(.+)$")
	table.insert(vdsg_catalogue, {id = id, content = content})
end
vdsg_catalogue["n"] = #vdsg_catalogue

command.new("vdsg", function( message )
	math.randomseed(os.clock())
	local tbl = vdsg_catalogue[math.random(1, vdsg_catalogue.n)]
	message.channel:send({
		embed = {
			title = "VDSG Catalogue No." .. tbl.id,
			description = tbl.content,
			timestamp = discordia.Date():toISO('T', 'Z')
		},
		color = discordia.Color.fromRGB(15, 255, 15).value,
		refrence = {message = message, mention = false}
	})
end, nil, "get a vault dweller survival guide tip", true)

local langton = require("./lua/langton/langton")

command.new("ant", function( message, arg )
	if arg[1] == "status" then
		local stats = langton.state()
		message.channel:send({
			embed = {
				title = "Langton Status",
				fields = {
					{name = "Pattern", value = stats.patternstr, inline = false},
					{name = "Ant Position", value = stats.position.x .. " " .. stats.position.y, inline = false},
					{name = "Step", value = tostring( stats.itteration ), inline = false},
				}
			}
		})
	else
		langton.step()
	end
end, "<status>", "progresses the current langton by one step")

local ai = require("./lua/api/15ai")

command.new("fifteenai", function( message, _, arg )
	if arg:match("^list") then
		local fields = {}
		for i,v in pairs(ai.getCharacter()) do
			table.insert(fields, {name = i, value = v:gsub(",%s*$", ""), inline = false})
		end
		message.channel:send({
			embed = {
				title = "15ai Catalog",
				description = "supports any of the voices on 15.ai",
				fields = fields
			},
			refrence = {message = message, mention = true}
		})
		return
	end
	message.channel:broadcastTyping()
	local character, content = arg:match("^%s*\"(.-)\"%s*(.-)$")
	c = ai.getCharacter( character or "" )
	if c == false then
		message.channel:send({embed = {description = "\"" .. character .. "\"", image = {url = "https://cdn.discordapp.com/emojis/851306893745717288.webp?size=128&quality=lossless"}}})
	elseif c then
		local result = ai.saveToFile(c, content, "15ai-" .. c:lower():gsub("%s", "%-") .. ".wav")
		if result.status ~= "OK" and not result.filename then output(result.status, "err") return end
		message.channel:send({
			content = "generated with 15.ai",
			file = result.filename
		})
	else
		message.channel:send("couldn't find character " .. character)
	end
end, "\"<character>\" <message>", "uses http://15.ai to generate a sound file")

local currentStream = nil

command.new("slowmode", function( message, arg )
	if message.author.id == _config.users.paul then
		local limit, duration = arg[1], arg[2]
		message.channel:setRateLimit(limit)
		output("set slowmode for channel " .. message.channel.name, "info")
	end
end, "<limit> <duration>", "sets the current channel to slowmode", true)

local garfield = require("./lua/api/garfield")

command.new("garfield", function( message )
	local result = garfield.getStrip(os.clock())
	if result.status ~= "OK" then output(result.status, "err") return end
	proxout(message.channel:send {
		embed = {
			image = {
				url = result.data.url
			},
			footer = {text = result.data.year .. "/" .. result.data.month .. "/" .. result.data.day}
		}
	})
end, nil, "gets a random garfield strip")

local google = require("./lua/api/google")

command.new("reverse", function( message )
	if not (message.referencedMessage or {}).attachment then output("error: no refrence message", "err") return end
	local ct = message.referencedMessage.attachment.content_type:lower()
	ct = ct:match("image/(.+)") or ct or "null"
	if not google.supportedImages[ct] then output("error: unsupported file type (" .. ct .. ")", "err") return end
	local results = google.reverseSearch( message.referencedMessage.attachment.url )
	if results.status ~= "OK" then output(results.data, "err") return end
	output(results.data)
end, nil, "reverse image searches for an image (google doesnt like this, can get taken down)")

command.new("restart", function( message ) os.exit() end, nil, "restarts server", false, {"manageWebhooks"})

local toremind = {}

command.new("remind", function( message, args )
	local t, c, m = args[1], args[2], args[3]
	if c == "d" then
		t = tonumber(t) * 1440
	elseif c == "h" then
		t = tonumber(t) * 60
	elseif c == "m" then
		t = tonumber(t)
	else
		output("could not parse time mode: " .. c, "warn") return
	end
	table.insert(toremind, {mentionString = message.member.mentionString, name = message.member.nickname or message.member.name, current = 0, total = t, message = m})
	proxout(message.channel:send({
		embed = {
			description = "reminder set for " .. t .. " minutes"
		}
	}))
end, "<time> <m/h/d>", "reminds you after a certain time period (note: if bot errors all current reminders are erased)")

dClock:on("min", function()
	for i in ipairs(toremind) do
		toremind[i].current = toremind[i].current + 1
		if toremind[i].current >= toremind[i].total then
			proxout(client:getChannel(_config.static.c_bot):send({
				content = toremind[i].mentionString,
				embed = {
					title = toremind[i].name .. "'s Reminder",
					description = toremind[i].message
				}
			}))
		end
	end
end)

command.new("pirate", function( message, _, arg )
	if arg:match("^%s*list%s*$") then
		local str = ""
		for i in io.lines("tables/pirate.txt") do
			str = str .. i:gsub("%s*http.-$", ",")
		end
		message.channel:send(str)
		return
	end
	local thing = ""
	for i in io.lines("tables/pirate.txt") do
		if i:lower():match(arg:lower()) then
			thing = i
			break
		end
	end
	print(thing)
	message.channel:send(thing:match("(http.-)$"))
end, "<movie>", "pirates a movie")

command.new("frequency", function(_, arg)
	local g = appdata.read("global.ini")
	local v = tonumber(arg[1])
	if v > 5000 then 
		v = 5000
	elseif v < 5 then
		v = 5
	end
	g:gsub("frequency=%d+", "frequency=" .. v)
end, "<url>", "set frequency of badding the bone." )

command.new("terraria", function( message )
	proxout(message.channel:send {
		embed = {
			title = "Bread Bag Terraria Server",
			fields = {
				{name = "Server IP Address", value = "null", inline = false},
				{name = "Server Port", value = server_info.terrariaport, inline = false},
				{name = "Server Password", value = server_info.terrariapass, inline = false},
			},
			description = server_info.terrariamotd,
		}
	})
end, "<movie>", "terraria server data")

local fBlacklist = {"privacy%.log", "player_download[\\/].*", "15ai[\\/].*", "directmessage[\\/].*", "http%.log", "incomingconnections%.log", "web[\\/].*"}

command.new("read", function( message, _, args )
	local black = false
	for _,v in ipairs(fBlacklist) do
		if args:match("^" .. v .. "$") then black = true break end
	end
	local f = appdata.get(args, "r")
	if f then
		if black then
			message.channel:send("file is blacklisted")
			f:close()
			return
		end
		proxout(message.channel:send {
			file = appdata.directory() .. args
		})
		f:close()
	else
		message.channel:send("could not find file")
	end
end, "<filename>", "read internal data from files inside the bot", true, {"manageWebhooks"})

command.new("say_video", function( message, _, url )
	local file = yt_downloader.get_srt(url)
end, "<string> <pattern>", "match some stuff idk", true, {"manageMessages"})

local privacies = {n = 0}

appdata.init({{"privacy.log", "0"}})

command.new("privacy", function( message )
	local f = appdata.get("privacy.log", "r")
	if not f:read("*a"):match("%s" .. message.author.id .. "%s?") then
		privacies[message.author.id] = message.channel.id
		privacies.n = privacies.n + 1
		proxout(message.channel:send {
			embed = {
				title = "Benbebot Privacy Policy",
				description = "View our privacy policy\n\nhttps://github.com/Benbebop/Benbebot/blob/main/tables/bullshitPrivacyPolicy.md#privacy-policy\n\nOnce you have read this, please send in this channel:",
				fields = {
					{name = "I Agree", value = "if you agree to our privacy policy", inline = false},
					{name = "I Disagree", value = "if you do not agree to our privacy policy", inline = false},
				},
				footer = {text = "This message was generated by " .. message.member.nickname .. " and only applies to them. To generate your own message send \"bbb privacy\" in this server."}
			}
		})
	else
		proxout(message.channel:send {
			embed = {
				title = "Benbebot Privacy Policy",
				description = "View our privacy policy\n\nhttps://github.com/Benbebop/Benbebot/blob/main/tables/bullshitPrivacyPolicy.md#privacy-policy"
			}
		})
	end
	f:close()
end, nil, "read our privacy policy")

client:on('messageCreate', function(message)
	if privacies.n > 0 then
		if privacies[message.author.id] == message.channel.id then
			if message.content:lower():match("^%s*i%s*agree%s*$") then
				local f = appdata.get("privacy.log", "a")
				f:write(" ")
				f:write(message.author.id)
				f:close()
				privacies[message.author.id] = nil
				privacies.n = privacies.n - 1
				output(message.author.mentionString .. " has accepted the Benbebot Privacy Policy", "info")
			elseif message.content:lower():match("^%s*i%s*disagree%s*$") then
				message.member:kick()
				privacies[message.author.id] = nil
				privacies.n = privacies.n - 1
				output(message.author.mentionString .. " has rejected the Benbebot Privacy Policy", "info")
			else
				message:delete()
			end
		end
	end
end)

command.new("issue", function( message )
	proxout(message.channel:send("if you encounter an error, report it here https://github.com/Benbebop/Benbebot/issues/new"))
end, nil, "report an issue with the bot")

command.new("update_msg", function( message )
	local r = githubAPI.release()
	if r then
		client:getChannel("955315272879849532"):send({embed = r})
	end
end, nil, "i cant be bothered to write this", true)

local tmpfile = io.lines("lua/encoder.lua")
local encode, encode_info = require("./lua/encoder"), tmpfile():gsub("^%s*%-%-%s*", "")

command.new("clear", function( message )
	
end, "<time>", "clears all messages up to a certain time ago", false, {"manageMessages"})

local sudoku = require("lua/sudoku").Create()

command.new("sudoku", function( message, args )
	sudoku:newGame()
	sudoku.level = tonumber(args[1] or "0")
	local output = ""
	for row=0,8 do
		for col=1,9 do
			output = output .. tostring(sudoku:getVal(row, col) or "?"):gsub("0", ".") .. " "
		end
		output = output .. "\n"
	end
	sudoku:solveGame()
	proxout(message.channel:send {
		embed = {
			description = "```\n" .. output .. "```",
			--footer = {text = String}
		}
	})
end, "<level>", "generate a sudoku puzzle or smthn", true)

command.new("sex", function( message )
	output("<@" .. message.author.id .. "> used sex", "info")
	message.author:send("GO FUCK YOURSELF")
	message.member:kick("GO FUCK YOURSELF")
end, nil, "FUCK YOU I DID IT", true)

command.new("nerd", function(message, _, stuff)
	local target = stuff
	if message.referencedMessage then target = message.referencedMessage.content end
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

command.new("everyone_watch", function( message )
	
end, nil, "if someone @/everyone then kills them", false, {"manageMembers"})

command.new("unpermarole", function( message )
	local target = message.mentionedUsers.first
	if target then
		if roleGiver.deletePermarole(target.id) then
			message:reply("deleted " .. target.mentionString .. "'s permarole profile")
			output(message.author.mentionString .. " deleted a permarole profile of " .. target.mentionString, "info")
		else
			message:reply("couldnt find permarole profile")
		end
	else
		message:reply("you must mention a member")
	end
end, "<target>", "forcefully removes permaroles", false, {"manageWebhooks"})

command.new("kill", function( message )
	local target = message.mentionedUsers.first
	if target then
		if roleGiver.deletePermarole(target.id) then
			message:reply("deleted " .. target.mentionString .. "'s permarole profile")
			output(message.author.mentionString .. " deleted a permarole profile of " .. target.mentionString, "info")
		else
			message:reply("couldnt find permarole profile")
		end
		target:kick()
	else
		message:reply("you must mention a member")
	end
end, nil, "removes all permaroles and kicks", false, {"manageWebhooks", "manageMembers"})

command.new("fuckyou", function( message )
	local target = message.mentionedUsers.first or message.referencedMessage.author
	local thing = require("./tables/videoindex")[target.id]
	if thing then
		message:reply(thing)
	end
end, nil, nil)

local server = require("./lua/srcds").create( os.getenv('LOCALAPPDATA'):sub(1,2) .. "/dedicatedserver/garrysmod/" )

--server:setAuth( tokens.getToken( 18 ) )

server:on(6,function() server:kill() end)
server:on(7,function(remaining) client:getChannel(_config.channels.game_server_output):send({embed = {description = "no players in server, " .. remaining .. " seconds until shutdown",color = server.gameColor}}) end)
server:on(8,function(err, addon) output("SRCDS Lua Error: (" .. addon .. ") " .. err, "err") end)

server:on(9,function(id) server:addDeath( id ) end) server:on(10,function(id) server:addFrag( id ) end) server:on(11,function(id) server:addTaunt( id ) end) server:on(12,function(id) server:addProp( id ) end)

server:on("shutdown",function()
	client:getChannel(_config.channels.game_server_output):send({
		embed = {
			title = "shutdown Garry's Mod server",
			color = server.gameColor
		}
	})
end)

server:on("playerKilled",function(victimName, weaponName, attackerName)
	if victimName ~= attackerName then
		client:getChannel(_config.channels.game_server_output):send({
			embed = {
				description = attackerName .. " killed " .. victimName .. " with " .. weaponName,
				color = server.gameColor
			}
		})
	end
end)

server:on("playerJoined",function(playerName, playerID, playerIP)
	client:getChannel(_config.channels.game_server_output):send({
		embed = {
			description = playerName .. " joined",
			color = server.gameColor
		}
	})
end)

server:on("playerLeft",function(playerName, playerID, reason)
	client:getChannel(_config.channels.game_server_output):send({
		embed = {
			description = playerName .. "  left",
			color = server.gameColor
		}
	})
end)

server:on("error",function(err)
	client:getChannel(_config.channels.game_server_output):send({
		embed = {
			description = "ServerConnectionError: " .. err,
			color = server.gameColor
		}
	})
end)

local accountQueue = {}

server:on("connectAccount",function(playerID, name, descriminator)
	local found = nil
	for member in client:getGuild(_config.static.myGuild).members:iter() do
		local user = member.user
		if user.name == name and user.discriminator == descriminator then
			found = user
			break
		end
	end
	if not found then
		server:send("accountFound", 0)
		return
	else
		server:send("accountFound", 1)
	end
	table.insert( accountQueue, found:getPrivateChannel():send({
		embed = {
			title = "Steam Account Confirmation",
			description = "verify that you wish to connect your discord account with the steam account `" .. playerID .. "`, react with thumbs up if you requested this, if you did not then react with thumbs down.",
			footer = {
				text = "this message is releated to the benbebot game server"
			},
			color = server.gameColor
		}
	}).id )
end)

local gamemodes, maps = server:listGamemodes(), server:listMaps()

command.new("server", function( message, args )
	local game = args[1]:lower()
	if game == "shutdown" then
		server:kill()
		return
	end
	if game == "garrysmod" or game == "gmod" then
		server:setMaxPlayers( math.max(math.min(tonumber(args[4]) or 32, 128), 2) )
		local exists = false
		for _,v in ipairs(gamemodes) do
			if (args[2] or gamemode) == v then
				exists = true
				server:setGamemode( v )
				break
			end
		end
		if args[2] and not exists then
			message:reply("could not find the specified Garry's Mod gamemode (for list do \"bbb serverinfo garrysmod gamemodes\")")
			return
		end
		exists = false
		for _,v in ipairs(maps) do
			if (args[3] or map) == v then
				exists = true
				server:setMap( v )
				break
			end
		end
		if args[3] and not exists then
			message:reply("could not find the specified Garry's Mod map (for list do \"bbb serverinfo garrysmod maps " .. gamemode .. "\")")
			return
		end
		server:newServer()
		local m = message:reply("starting Garry's Mod server (gamemode:" .. server:getArgGamemode() .. ",map:" .. server:getArgMap() .. ",maxplayers:" .. server:getArgMaxPlayers() .. ")")
		local success, result = server:waitForServer( 10000 )
		if not success then
			m:setContent("there was a problem starting the Garry's Mod server: " .. result)
			--server:kill()
		else
			m:setContent("succesfully started Garry's Mod server")
			client:getChannel(_config.channels.game_server_output):send({
				embed = {
					title = "started Garry's Mod server",
					description = "[connect](steam://connect/p2p:" .. 0 .. ")",
					color = server.gameColor
				}
			})
		end
	elseif game == "tf2" then
		message:reply("game not implemented")
	elseif game == "csgo" or game == "cs:go" then
		message:reply("game not implemented")
	elseif game == "minecraft" or game == "mc" then
		message:reply("game not implemented")
	elseif game == "terraria" then
		message:reply("game not implemented")
	else
		message:reply("game does not exist")
	end
end, "<game> <opts>", "start or vote to start a game server", false, {"manageWebhooks"})

command.new("serverinfo", function( message, args )
	if args[1] == "garrysmod" then
		if args[2] == "gamemodes" then
			local m = message:reply("fetching gamemodes")
			gamemodes = server:listGamemodes()
			local str = ""
			for _,v in ipairs(gamemodes) do
				str = str .. v .. ", "
			end
			m:setContent(str)
		elseif args[2] == "maps" then
			local m = message:reply("fetching maps")
			local gamemode = (not tonumber(args[3])) and args[3]
			if gamemode then
				local m = server:listMapsByGamemode(gamemode)
				if not m then
					m:setContent("could not find the specified Garry's Mod gamemode (for list do \"bbb serverinfo garrysmod gamemodes\")")
					return
				end
				maps = m
			else
				maps = server:listMaps()
			end
			local str, page = "", tonumber(args[3]) or tonumber(args[4]) or 1
			local pageStart, pageEnd = 1 + (page - 1) * 20, 1 + page * 20
			if not maps[pageStart] then
				m:setContent("page out of range")
			end
			for i=pageStart,pageEnd do
				if not maps[i] then
					break
				end
				str = str .. maps[i].name .. ", "
			end
			if maps[pageEnd + 1] then
				str = str:sub(1, -3) .. "..."
			else
				str = str:sub(1, -3)
			end
			m:setContent(str)
		elseif args[2] == "map" then
			maps = server:listMaps()
			local map
			for _,v in ipairs(maps) do
				if v.name == args[3] then
					map = v
					break
				end
			end
			local icon = fs.existsSync(map.dir .. "thumb/" .. map.name .. ".png") and map.dir .. "thumb/" .. map.name .. ".png" or fs.existsSync(map.dir .. map.name .. ".png") and map.dir .. map.name .. ".png"
			local hasNavigation, hasNodes, hasCredit = fs.existsSync(map.dir .. map.name .. ".nav"), fs.existsSync(map.dir .. "graphs/" .. map.name .. ".ain"), fs.existsSync(map.dir .. map.name .. ".credit")
			local authorName, authorLink, pageName, pageLink
			if hasCredit then
				pageName, pageLink, authorName, authorLink = string.unpack("zzzz", fs.readFileSync(map.dir .. map.name .. ".credit"))
			end
			local csDependent, csasset = false, server:open("cssource.ast", "rb")
			for _,v in ipairs(server.getVBSPContent( map.dir .. map.name .. ".bsp" )) do
				server.compareAsset(csasset, v)
			end
			csasset:close()
			message:reply({
				embed = {
					title = map.name,
					description = "[" .. (pageName or map.name) .. "](" .. (pageLink or "") .. ")\nby [" .. (authorName or "Unknown") .. "](" .. (authorLink or "") .. ")",
					fields = {
						{name = "Navmesh", value = tostring(hasNavigation), inline = true},
						{name = "Node Graph", value = tostring(hasNodes), inline = true},
					},
				},
				file = icon
			})
		elseif args[2] == "players" then
			local player = server:getPlayer( args[3] )
		elseif args[2] == "joinguide" then
			message:reply(helpText.joingmod)
		else
			message:reply("did not recognize arg[2]")
		end
	else
		
	end
end, "<opts>", "server stuff")

-- WEBHOOKS --

local webhook = require("./lua/webhook")

appdata.init({{"incomingconnections.log"}})

webhook.create(nil, server_info.youtubeport, function(req, body)
	local m = "method: " .. req.method .. "\npath: " .. req.path .. "\nversion: " .. req.version .. "\nHEADERS: \n"
	local i = 1
	repeat
		local h = req[tostring(i)]
		m = m .. h[1] .. ": " .. h[2] .. "\n"
		i = i + 1
	until not req[tostring(i)]
	m = m .. "BODY: " .. body
	appdata.append("incomingconnections.log", "\n------------\n" .. m)
	output("SERVER CONNECTION: " .. m, "http")
end)

local sha256 = require("./lua/hash/sha2")

local auth_tokens = {}

appdata.init({{"web/"},{"web/whitelist.dat", ""},{"web/blacklist.dat", ""}})

local function checkAuthorized(auth, ip)
	local authorized = false
	if auth then
		for _,v in ipairs(auth_tokens) do
			if v == auth then 
				authorized = true
				break
			end
		end
	end
	if authorized then
		local c1, c2, c3 = ip:match("(%d+)%.(%d+)%.(%d+)%.%d+")
		local ipEncoded = string.pack("I1I1I1", tonumber(c1), tonumber(c2), tonumber(c3))
		local auth, black = appdata.get("web/whitelist.dat", "rb"), appdata.get("web/blacklist.dat", "rb")
		local recognized, blacklisted = false, false
		repeat
			local a, b = auth:read(3), black:read(3)
			if s == ipEncoded then
				recognized = true
				break
			end
			if b == ipEncoded then
				blacklisted = true
			end
		until (not s) and (not b)
		auth:close() black:close()
		if recognized then
			return true
		elseif blacklisted then
			return false, {405, "Method Not Allowed"}
		else
			client:getUser(_config.users.ben):getPrivateChannel():send({
				embed = {
					title = "NEW IP CONNECTION",
					description = ip
				}
			})
			appdata.append("web/blacklist.dat", ipEncoded)
			return false, {405, "Method Not Allowed"}
		end
	else
		return false, {401, "Unauthorized"}
	end
end

webhook.create(nil, server_info.youtubeadport, function(req, headers, body, tcp)
	if req.path == "/" then
		local file = io.open("resource/webpage/redirect.html", "rb")
		local html = file:read("*a")
		file:close()
		return {{"Location", "http://" .. server_info.ip .. ":8646/login"},{"Connection", "keep-alive"}}, nil, 308, "Permanent Redirect"
	elseif req.path:sub(1, 11) == "/login-page" then
		local file = io.open("resource/webpage/login.html", "rb")
		local html = file:read("*a")
		file:close()
		return nil, html, 200, nil, "text/html"
	elseif req.path:sub(1, 6) == "/login" then
		if req.method == "GET" then
			local file = io.open("resource/webpage/redirect.html", "rb")
			local html = file:read("*a")
			file:close()
			return {{"Location", "http://" .. server_info.ip .. ":8646/login-page"},{"Connection", "keep-alive"}}, nil, 308, "Permanent Redirect (use method POST)"
		elseif req.method == "POST" then
			if body == "pass=i+love+big+dicks" then
				local token = ""
				for _=1,16 do
					local charindex = math.random(62)
					token = token .. string.char(charindex + (charindex > 36 and 13 or (charindex > 10 and 7) or 0) + 47)
				end
				table.insert(auth_tokens, token)
				return nil, token, 200
			else
				local file = io.open("resource/webpage/failed.html", "rb")
				local html = file:read("*a")
				file:close()
				return nil, html, 200, nil, "text/html"
			end
		else
			return nil, nil, 405, "Method Not Allowed"
		end
	elseif req.path:sub(1, 7) == "/signup" then
		if req.method ~= "POST" then return nil, nil, 405, "Method Not Allowed" end
		return nil, nil, 501, "Not Implemented"
	elseif req.path:sub(1, 7) == "/upload" then
		if req.method ~= "POST" then return nil, nil, 405, "Method Not Allowed" end
		local sock = tcp:getpeername().ip
		local auth, err = checkAuthorized(headers.Authorization, sock)
		if auth then
			local data = json.decode(body)
			if data and data.addebug_videoId then
				return nil, nil, 200, "Success"
			elseif data then
				return nil, nil, 422, "Unprocessable Entity"
			else
				return nil, nil, 400, "Bad Request"
			end
		else
			return nil, nil, err[1], err[2]
		end
	elseif req.path:sub(1, 5) == "/list" then
		if req.method ~= "GET" then return nil, nil, 405, "Method Not Allowed" end
	else
		return nil, nil, 404, "Page Not Found"
	end
end, "resource/webpage/favicon.ico")

--client:on("ready", function() client:getUser(_config.users.ben):getPrivateChannel() end)

client:on('reactionAdd', function(reaction)
	p(id, _config.users.ben)
	if id == _config.users.ben then
		local message = reaction.message
		p(message.embed)
	end
end)

-- Role Giver --
initFile = io.open("tables\\roleindex.json", "rb")
local basicRoles = json.parse(initFile:read("*a"))
initFile:close()

local dCheck = {}

client:on("memberJoin", function(member)
	local permroles = roleGiver.listPermaroles(member.id)
	if permroles then -- get if profile exists
		for i,v in pairs(permroles) do -- go through profile
			if member.guild:getRole(i) then -- role exists
				local success, err = member:addRole(i) -- give role from profile
				if not success then -- if there was an error
					output("PermaroleError (could not add permarole " .. member.guild:getRole(i).name .. " to " .. member.name .. " [" .. err:gsub("\n", " ") .. "])", "err")
				elseif not member:hasRole(i) then -- if no error but still doesnt have role
					output("PermaroleError (addRole failed, no error)", "err")
				else -- success
					output("added permarole \"" .. member.guild:getRole(i).name .. "\" to " .. member.name, "info")
					table.insert(dCheck, {member.guild.id, member.id})
				end
			elseif not client:getRole(i) then
				output("PermaroleError (permarole <@" .. i .. "> no longer exists)", "err")
				roleGiver.removePermarole( member.id, i )
			end
		end
	end
end)

dClock:on("min", function() -- fix for role giver bug
	if #dCheck ~= 0 then
		output("dChecking permaroles", "info")
		for i,v in ipairs(dCheck) do
			local member = client:getGuild(v[1]):getMember(v[2])
			for _,l in ipairs(roleGiver.listPermaroles(member.id)) do
				member:addRole(l)
				if member:hasRole(l) then
					table.remove(dCheck, i)
				end
				output("added permarole \"" .. client:getRole(l).name .. "\" to " .. member.name, "info")
			end
			output("dChecked permarole for " .. member.name, "info")
		end
	end
end)

local function permaroleReply( message ) 
	if message.channel.id ~= _config.channels.role_giver then
		message:reply("role commands are for use in " .. client:getChannel(_config.channels.role_giver).mentionString .. " and also dont have bbb in front of them, dumbass") 
	else
		message:reply("role commands dont have bbb in front of them you dumbass") 
	end
end

command.new("role", permaroleReply, nil, nil, true)
command.new("unrole", permaroleReply, nil, nil, true)
command.new("permarole", permaroleReply, nil, nil, true)
command.new("unpermarole", permaroleReply, nil, nil, true)

client:on('messageCreate', function(message)
	local content = message.content:lower()
	if message.channel.id == _config.channels.role_giver and message.author.id ~= _config.static.myId then
		local add_str = content:match("^%s*role%s*(.-)%s*$") local sub_str = content:match("^%s*unrole%s*(.-)%s*$") 
		local perm_str = content:match("^%s*permarole%s*(.-)%s*$") local unperm_str = content:match("^%s*unpermarole%s*(.-)%s*$")
		if add_str then -- add a role
			output("i was to lazy to reimplement this sorry, you should yell at me <@" .. _config.users.ben .. ">", "err")
		elseif sub_str then -- remove a role
			output("i was to lazy to reimplement this sorry, you should yell at me <@" .. _config.users.ben .. ">", "err")
		elseif perm_str then -- add a permarole
			if perm_str == "all" then -- give permaroles by member roles
				local add = {}
				message.member.roles:forEach(function(r)
					table.insert(add, r.id)
				end)
				local _, count = roleGiver.addPermarole( message.author.id, add )
				message:reply("added " .. count .. " roles to " .. message.author.mentionString .. "'s permarole profile")
			elseif perm_str == "get" then
				local roles = roleGiver.listPermaroles( message.author.id )
				if roles then
					local role_str = ""
					for _,v in ipairs(roles) do
						local role = client:getRole(v)
						if role then
							role_str = role_str .. role.name .. ", "
						end
					end
					message:reply(message.author.mentionString .. "'s permarole profile:\n" .. role_str:sub(1, -3))
				else
					message:reply(message.author.mentionString .. "'s permarole profile is empty")
				end
			elseif perm_str:match("^%d+$") then -- give permarole by id
				local role = client:getRole(perm_str)
				if role then
					roleGiver.addPermarole( message.author.id, role.id )
					message:reply("added role " .. role.name .. " to " .. message.author.mentionString .. "'s permarole profile")
				else
					message:reply("no role exists for id " .. perm_str)
				end
			else -- give role by name
				local role = roleGiver.checkPatterns( client:getGuild(_config.static.myGuild).roles, perm_str )
				if role then
					roleGiver.addPermarole( message.author.id, role )
					message:reply("added role " .. client:getRole(role).name .. " to " .. message.author.mentionString .. "'s permarole profile")
				else
					message:reply("could not find role " .. perm_str)
				end
			end
		elseif unperm_str then -- remove a permarole
			if unperm_str == "all" then -- remove all permaroles
				roleGiver.deletePermarole( message.author.id )
				message:reply("deleted " .. message.author.mentionString .. "'s permarole profile")
			elseif unperm_str:match("^%d+$") then -- remove permarole by id
				local role = client:getRole(unperm_str)
				if role then
					roleGiver.removePermarole( message.author.id, role.id )
					message:reply("removed role " .. client:getRole(role).name .. " from " .. message.author.mentionString .. "'s permarole profile")
				else
					message:reply("no role exists for id " .. unperm_str)
				end
			else
				local role = roleGiver.checkPatterns( client:getGuild(_config.static.myGuild).roles, unperm_str )
				if role then
					roleGiver.removePermarole( message.author.id, role )
					message:reply("removed role " .. client:getRole(role).name .. " from " .. message.author.mentionString .. "'s permarole profile")
				else
					message:reply("could not find role " .. unperm_str)
				end
			end
		end
	end
end)

-- Fun --
local char = string.char
initFile = io.open("tables\\characterreplacers.json", "rb")
local characterReplacers = json.parse(initFile:read("*a"))
initFile:close()
local latestDelMsg, latestDelAuth, latestDelAttach = "", "", {}
local soundcloud = require("./lua/api/soundcloud")

local latestMotd = {id = "", meansent = false}

local sendMotd = function( skip )
	if not _config.misc.motd then return end
	githubAPI.applyMotd()
	local mashup, nextMashup, count, index = soundcloud.getMashup(), soundcloud.nextMashup(), soundcloud.count()
	if nextMashup then
		client:getUser(_config.users.ben):getPrivateChannel():send("next Mashup of The Day: https://soundcloud.com/" .. nextMashup .. " (" .. index .. "/" .. count .. " " .. math.floor( index / count * 100 ) .. "%)")
	else
		client:getUser(_config.users.ben):getPrivateChannel():send("no existing next Mashup of The Day!")
	end
	if not skip then
		if mashup then
			local message = client:getGuild(_config.static.myGuild):getChannel(_config.static.c_announcement):send("https://soundcloud.com/" .. mashup)
			latestMotd.id = message.id
			message:addReaction("👍")
			message:addReaction("👎")
			message:addReaction("🖕")
		else
			client:getGuild(_config.static.myGuild):getChannel(_config.static.c_announcement):send("someone fucked up and there aint any mashup of the day!!!!!")
		end
	end
end

client:on('reactionAdd', function(reaction)
	local message = reaction.message
	if message.id == latestMotd.id and (not latestMotd.meansent) then
		local positive = message.reactions:find(function(v) return v.emojiName == "👍" end)
		local negitive = message.reactions:find(function(v) return v.emojiName == "👎" end)
		local middle_finger = message.reactions:find(function(v) return v.emojiName == "🖕" end)
		if positive and negitive and middle_finger then
			positive, negitive, middle_finger = positive.count - 1, negitive.count - 1, middle_finger.count - 1 
			local total = positive + negitive + middle_finger
			local meanness = middle_finger / total
			client:getUser(_config.users.ben):getPrivateChannel():send("meanness: " .. meanness)
			if meanness > 0.75 and total > 5 + 3 then
				proxout(client:getGuild(_config.static.myGuild):getChannel(_config.static.c_announcement):send({
					content = "why is everyone so mean to me?",
					file = "images/mean.jpg",
					reference = {
						message = latestMotd.id,
						mention = false,
					}
				}))
				latestMotd.meansent = true
			end
		end
	end
end)

client:on('messageCreate', function(message)
	if message.channel.id == client:getUser(_config.users.ben):getPrivateChannel().id then
		if message.content:match("^%s*motd%sskip") then
			sendMotd( true )
		end
	end 
end)

dClock:on("hour", function()
	if os.date("%H") == soundcloud.getPostTime() then
		sendMotd()
	end
end)

client:on('messageCreate', function(message)
	if message.channel.id == client:getUser(_config.users.ben):getPrivateChannel().id then
		if message.content:match("^%s*update%s*privacy") then
			local f = appdata.get("privacy.log", "r")
			for i in f:read("*a"):gmatch("%d+") do
				if client:getUser(i) then
					proxout(client:getUser(i):send( {
						embed = {
							title = "Benbebot Privacy Policy",
							description = "We have updated our privacy policy, please read it here:\n\nhttps://github.com/Benbebop/Benbebot/blob/main/tables/bullshitPrivacyPolicy.md#privacy-policy"
						}
					} ))
				end
			end
		end
	end
end)

client:on('messageCreate', function(message) --random shit
	if message.channel.id == "862470542607384596" then -- AMONG US VENT CHAT --
		if message.content:lower():match("amo%a?g%s?us") then
			message.member:addRole("823772997856919623")
			output(message.author.name .. " said among us in #rage-or-vent", "mod")
			message.channel:send("you are unfunny :thumbsdown:")
		end
	elseif message.author.id == _config.users.arcane and message.content:match("please do not use blacklisted words!") and latestDelAuth ~= "941372431082348544" and ( (not _config.misc.seventysix_mode) or lastDel76 ) then -- F --
		local translatedMsg = latestDelMsg
		local tofar = latestDelMsg:lower():match(char(110) .. char(105) .. char(103) .. char(103) .. char(101) .. char(114))
		for i,v in pairs(characterReplacers) do
			translatedMsg:gsub(i, v)
		end
		local fomessage = message:reply("fuck off " .. message.author.name .. " :middle_finger:")
		if tofar then
			message:reply("actually nevermind that message was too far")
			--output(message.author.name .. " is saying racial slurs", "mod")
		elseif _config.misc.seventysix_mode and not lastDel76 then
			message:delete()
			return
		else
			local attachStr = ""
			if latestDelAttach then
				for i,v in ipairs(latestDelAttach) do
					attachStr = attachStr .. v.url .. "\n"
				end
			end
			message.channel:send({
				content = message.mentionedUsers.first.name .. ": " .. translatedMsg .. "\n" .. attachStr
			})
			message:delete()
			--output(message.author.name .. " was succesfully blocked", "mod")
		end
		local mbefore = message.channel:getMessagesBefore(fomessage.id, 1)
		if mbefore:iter()().author.id == _config.static.myId then
			fomessage:delete()
		end
	elseif message.author.id == _config.users.ben and message.channel.id == _config.static.c_bot and message.content:match("force motd 12345") then
		message:delete()
		sendMotd()
	end
end)

client:on('messageDelete', function(message) -- deleted message logging
	latestDelMsg, latestDelAuth, latestDelAttach, lastDel76 = message.content, message.author, message.attachments, message.member:hasRole(_config.roles.seventysix_role)
end)

--AUTO NAME ROLES--

client:on('memberUpdate', function(member)
	local employed = false
	for i,v in ipairs(forceEmployed) do
		if member.id == v then
			employed = true
			break
		end
	end
	if _config.roles.gang_weed_autorole and member.nickname and member.nickname:match("^%s*gang%s+weed%s*$") then
		member:addRole(_config.users.gang_weed)
	elseif employed then
	elseif _config.roles.company_autorole and member.nickname and member.nickname:match(company.autoemploy) then
		member:addRole("930996065329631232")
		local result = websters.getDefinition( member.nickname:match("%a+ier%s*$"):gsub("%s", "") )
		if result.status ~= "OK" then output("something went wrong idk im too tired to write this error code, ill understand it ether way.", "err") end
		local success, _, found = result.data[1], result.data[2], result.data[3]
		if not success then
			output(member.user.mentionString .. " API usage exeded, contact a mod or wait an hour bitch. https://tenor.com/view/grrr-heheheha-clash-royale-king-emote-gif-24764227", "warn")
			return
		end
		if found then
			member:addRole("930996065329631232")
		else
			member:removeRole("930996065329631232")
			output("so close, but \"" .. member.nickname:match("%a+ier%s*$"):gsub("%s", "") .. "\" isnt a real word! If you think this is a mistake please ask a mod. " .. member.user.mentionString, "info")
		end
	else
		if _config.roles.gang_weed_autorole then
			member:removeRole("880305120263426088")
		end
		if _config.roles.company_autorole then
			member:removeRole("930996065329631232")
		end
	end
end)

dClock:on("day", function() -- no dank memer monday
	if os.date("%a") == "Mon" then
		local DankMemer = client:getGuild(_config.static.myGuild):getMember(_config.users.dankmemer)
		for id in pairs(DankMemer.roles) do
			DankMemer:removeRole(id)
		end
		DankMemer:addRole("951697964177428490")
	else
		local DankMemer = client:getGuild(_config.static.myGuild):getMember(_config.users.dankmemer)
		DankMemer:removeRole("951697964177428490")
		DankMemer:addRole("829754598327320607")
		DankMemer:addRole("822960808812216350")
	end
	setHoliday( holiday() )
end)

client:on('messageCreate', function(message) -- fuck off dank memer, your not funny
	if message.author.id == _config.users.dankmemer then
		if message.member:hasRole("951697964177428490") then
			message:delete()
		end
	end
end)

client:on('messageCreate', function(message) -- delete messages in output channel
	if message.channel.id == _config.channels.bot_output and message.author.id ~= "941372431082348544" then
		message:delete()
	end
end)

--DM LOGGING--

appdata.init({{"directmessage/"}})

client:on('messageCreate', function(message)
	if message.channel.type == 1 then
		appdata.append("directmessage/" .. message.author.name .. ".log", message.content .. "\n")
	end
end)

--ACTIVE ROLE STUFF--

appdata.init({{"lastposted.log"}})

local lp = appdata.read("lastposted.log")

client:on('messageCreate', function(message)
	lp = appdata.read("lastposted.log")
	if not message.author.bot and message.member then
		if lp:match("\n" .. message.author.id .. " ([%d%.]+)") then
			lp = lp:gsub("(\n" .. message.author.id .. ") [%d%.]+", "%1 " .. message:getDate():toSeconds())
		else
			lp = lp .. "\n" .. message.author.id .. " " .. message:getDate():toSeconds()
		end
		appdata.write("lastposted.log", lp)
		message.member:addRole(_config.roles.active_member)
	end
end)

local function checkposted( member )
	lp = appdata.read("lastposted.log")
	local balls = lp:match("\n" .. member.id .. " ([%d%.]+)")
	if balls then
		if discordia.Date() - discordia.Date().fromSeconds(balls) > discordia.Time.fromSeconds(2.628e+6) then
			member:removeRole(_config.roles.active_member)
			lp:gsub("\n" .. member.id .. " ([^\n]+)", "")
			appdata.write("lastposted.log", "w")
			output("removed " .. member.mentionString .. "'s member role for inactivity")
		end
	else
		output(member.mentionString .. " is absent from the checkposted file. removing member role.")
		member:removeRole(_config.roles.active_member)
	end
end

command.new("lastposted", function( message, args )
	lp = appdata.read("lastposted.log")
	local member = message.mentionedUsers.first or {id = args[1]}
	local t = lp:match("\n" .. member.id ..  " ([%d%.]+)")
	if not t then
		proxout(message.channel:send({
			embed = {
				description = "last posted not recorded"
			}
		}))
		return
	end
	t = discordia.Date() - discordia.Date().fromSeconds(t)
	proxout(message.channel:send({
		embed = {
			description = math.floor(t:toSeconds() / 86400) .. " days ago"
		}
	}))
end, "<user>", "", true)

dClock:on("day", function()
	client:getRole(_config.roles.active_member).members:forEach(checkposted)
end)

command.new("member_scan", function( message )
	if message.author.id == _config.users.ben then
		client:getRole(_config.roles.active_member).members:forEach(checkposted)
	end
end, "", "scans all users in guild for posting in the last 4 weeks")

--SERVER BOOST EVENTS--

appdata.init({{"boosts.log"}})

client:on('memberUpdate', function(member) --boost event FALLBACK
	if member.guild and (not member.guild.systemChannelId) and member.premiumSince then
		if (discordia.Date() - discordia.Date.parseISO(member.premiumSince)):toSeconds() <= 2 then
			client:emit("memberBoost", member)
		end
	end
end)

client:on('messageCreate', function(message) --boost event
	if message.guild and message.guild.systemChannel then
		if message.type == 8 then
			client:emit("memberBoost", message.member)
		end
	end
end)

client:on('memberBoost', function(member) -- ban on boost
	appdata.append("boosts.log", "lvl: " .. member.guild.premiumTier .. ", user: " .. member.user.name)
	output("some shithead (" .. member.user.mentionString .. ") actually boosted the server")
	member.user:send("ok listen man, you gotta use your money better okay. We do not take kindly to boosting around these parts. Goodbye!")
	proxout(member:ban("not good with money"))
end)

--BAN AND KICK NOTIFS--

-- client:on('userBan', function(user, guild)
	-- local ban = guild:getBan(user.id)
	-- local reason = ""
	-- if ban.reason then
		-- reason = "\n\nreason: " .. ban.reason
	-- end
	-- user:send("you got banned from Bread Bag bitch!!!!" .. reason)
-- end)

-- local invite_channels = {"844020172851511296", "872304924455764058"}

-- client:on('userUnban', function(user, guild)
	-- user:send("you are unbanned from Bread Bag now. heres a link to get you back in: https://discord.gg/" .. guild:getChannel(invite_channels[math.random(1, #invite_channels)]):createInvite({max_age = 0, max_uses = 1}).code)
-- end)

client:on('messageCreate', function(message) -- react when vective talks in all caps
	if message.author.id == _config.users.vective and #message.content > 5 and message.content:match("^%L$") and message.content:match("%u") then
		message:addReaction("<:penus:989950618481360896>")
	end
end)

client:on('messageCreate', function(message) -- ban ben when bbb mike is mentioned
	if message.content:match("bbb%s*mike") or message.content:match("benbebot%s*mike") and not message.author.bot then
		local ben = message.guild:getMember(_config.users.ben)
		if ben then
			ben:kick()
			output(message.author.mentionString .. " this annoying fuck scared ben off again", "info")
		end
	end
end)

client:on('messageCreate', function(message)
	if message.channel.id == _config.channels.seventysix_channel and not message.member:hasRole(_config.roles.seventysix_role) and not message.author.bot then
		message:delete()
	end
end)

dClock:on("wday", function(day)
	if day == 6 then
		output("benbebot will be shutdown for a short period of time for weekly maintenace", "info")
		os.execute("shutdown -r")
	end
end)

client:on('messageCreate', function(message)
	if _config.misc.goblin_mode and not message.author.bot then
		message:reply({content = "https://www.patreon.com/benbebop", reference = {
			message = message,
			mention = false,
		}})
	end
end)

client:run('Bot ' .. tokens.getToken( 1 ))