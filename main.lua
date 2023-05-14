VERSION = "3.78"

local uv, fs, appdata, server = require("uv"), require("fs"), require("data"), require("server")

require("./load-deps.lua")

local discordia = require("discordia")
local enums = discordia.enums
local clock = discordia.Clock()

local logLevel = require("los").isProduction() and 3 or 4
fs.mkdirSync(appdata.path("logs"))
local benbebot, familyGuy, cannedFood = discordia.Client({logFile=appdata.path("logs/bbb_discordia.log"),gatewayFile=appdata.path("logs/bbb_gateway.json"),logLevel=logLevel})
local familyGuy = discordia.Client({logFile=appdata.path("logs/fg_discordia.log"),gatewayFile=appdata.path("logs/fg_gateway.json"),logLevel=logLevel})
local cannedFood = discordia.Client({logFile=appdata.path("logs/cf_discordia.log"),gatewayFile=appdata.path("logs/cf_gateway.json"),logLevel=logLevel})
benbebot._logger:setPrefix("BBB") familyGuy._logger:setPrefix("FLG") cannedFood._logger:setPrefix("CNF")
benbebot._logChannel, familyGuy._logChannel, cannedFood._logChannel = "1091403807973441597", "1091403807973441597", "1091403807973441597"
local privateServer = server.new("0.0.0.0", 26420)
local publicServer = privateServer:new(26430)

benbebot:defaultCommandCallback(function(interaction)
	interaction:reply({embed = {
		description = "couldnt find command, [please report this error](https://github.com/Benbebop/benbebots/issues)"
	}})
end)

local BOT_GUILD = "1068640496139915345"
local TEST_CHANNEL = "1068657073321169067"

-- BENBEBOTS SERVER --
	
do -- log dms
	
	familyGuy:on("messageCreate", function(message)
		if message.channel.type ~= 1 then return end
		if message.author.id == familyGuy.user.id then return end
		
		local cat = familyGuy:getChannel("1068641046852022343")
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
	end)
	
end

do -- reaction roles
	
	benbebot:on("ready", function()
		benbebot:getChannel("1075203623073632327"):getMessage("1077041796779094096"):setContent(
[[@everyone You know how this works
	<@&1075196966654451743> :face_holding_back_tears: - major updates involving the bots
	<@&1068664164786110554> :video_game: - game server events
	<@&1075245976543056013> :flag_pl: - polls involving this server
	<@&1072698350836662392> :sleeping: - get pinged when the bot's pfps are updated
	<@&1078400699802587136> :skull: - get pinged whenever i feel the urge to kill]]
		)
	end)

	local rolesIndex = {
		["\240\159\165\185"] = "1075196966654451743",
		["\240\159\142\174"] = "1068664164786110554",
		["\240\159\135\181\240\159\135\177"] = "1075245976543056013",
		["\240\159\152\180"] = "1072698350836662392",
		["\240\159\146\128"] = "1078400699802587136",
	}
	
	local function add(_, messageId, hash, userId)
		if messageId == "1077041796779094096" then
			local role = rolesIndex[hash]
			if not role then return end
			benbebot:getGuild("1068640496139915345"):getMember(userId):addRole(role)
		end
	end
	
	local function remove(channel, messageId, hash, userId)
		if messageId == "1077041796779094096" then
			local role = rolesIndex[hash]
			if not role then return end
			benbebot:getGuild("1068640496139915345"):getMember(userId):removeRole(role)
		end
	end
	
	benbebot:on("reactionAddUncached", add)
	benbebot:on("reactionAdd", function(reaction, userId) add(reaction.message.channel, reaction.message.id, reaction.emojiHash, userId) end)
	
	benbebot:on("reactionRemoveUncached", remove)
	benbebot:on("reactionRemove", function(reaction, userId) remove(reaction.message.channel, reaction.message.id, reaction.emojiHash, userId) end)
	
end

do -- server owner role
	
	local function add(guild)
		local owner = guild.client:getGuild("1068640496139915345"):getMember(guild.ownerId)
		if owner then owner:addRole("1068721381178617896") guild.client:output("info", "added server owner role to %s", owner.name) end
	end
	benbebot:on("guildCreate", add)
	familyGuy:on("guildCreate", add)
	
	local function check(guild)
		local b, f = benbebot:getGuild(guild.id), familyGuy:getGuild(guild.id)
		if not (b and b.me or f and f.me) then
			local owner = guild.client:getGuild("1068640496139915345"):getMember(guild.ownerId)
			if owner then 
				owner:removeRole("1068721381178617896") 
				guild.client:output("info", "removed server owner role from %s", owner.name) 
			else
				guild.client:output("error", "failed to find owner of guild %s and remove server owner role", guild.name)
			end
		end
	end
	benbebot:on("guildDelete", check)
	familyGuy:on("guildDelete", check)
	
end

do -- soundclown
	
	local json, http, los = require("json"), require("coro-http"), require("los")
	
	local STATION = "https://soundcloud.com/discover/sets/weekly::%s"
	local TRACK = "https://api-v2.soundcloud.com/tracks?ids=%s&client_id=%s"
	
	local function createWeekHour(date)
		date.whour = (date.wday - 1) * 24 + date.hour
	end
	
	local function func(date)
		
		local res, body = http.request("GET", string.format(STATION, "benbebop"))
		if not (res and (res.code == 200) and body) then benbebot:output("error", "failed to get soundcloud station: %s", res.reason or tostring(res.code)) return end
		
		local stationContent = body:match("window.__sc_hydration%s*=%s*(%b[])")
		if not stationContent then benbebot:output("error", "soundcloud station: could not locate hydration content") return end
		
		stationContent = json.parse(stationContent)
		if not stationContent then benbebot:output("error", "soundcloud station: hydration content is not valid json") return end
		
		local stationPlaylist
		for _,v in ipairs(stationContent) do if v.hydratable == "systemPlaylist" then stationPlaylist = v.data end end
		if not stationPlaylist then benbebot:output("error", "soundcloud station: could not locate hydratable systemPlaylist") return end
		if stationPlaylist.playlist_type ~= "PLAYLIST" then benbebot:output("error", "soundcloud station: systemPlaylist is not a playlist: %s", stationPlaylist.playlist_type) return end
		
		local stationTracks = stationPlaylist.tracks
		if not stationTracks then benbebot:output("error", "soundcloud station: playlist has no tracks") return end
		
		--table.remove(stationTracks, 1) -- first result is always by the creator, get rid of it
		
		local client_id
		for url in body:gmatch("crossorigin%s*src=[\"']([^\"']+)") do -- im not very good at scraping, this works but is incredibly slow, whatever 
			local _, body = http.request("GET", url)
			client_id = body:match("[\"']client_id=([^\"']+)")
			if client_id then break end
		end
		if not client_id then benbebot:output("error", "soundcloud station: failed to scrape client_id") return end
		
		local index = math.floor(date.whour / 6)
		if not stationTracks[index] then benbebot:output("error", "Could not index station track: %s", index)
		local res, body = http.request("GET", string.format(TRACK, stationTracks[index].id, client_id))
		if not (res and (res.code == 200) and body) then benbebot:output("error", "failed to get soundcloud track: %s", res.reason or tostring(res.code)) return end
		
		local trackData = (json.parse(body) or {})[1]
		if not (trackData and trackData.permalink_url) then benbebot:output("error", "soundcloud station: track content is not valid") return end
		
		benbebot:getChannel(los.isProduction() and "1096581265932701827" or TEST_CHANNEL):send(trackData.permalink_url)
		benbebot:output("info", "sent mashup of the day: %s (index %d)", trackData.title, index)
		
	end
	
	clock:on("hour", function(date)
		createWeekHour(date)
		if date.whour % 6 == 0 then func(date) end
	end)
	
	benbebot:getCommand("1103908487278379110"):used({}, function(interaction, args)
		local date = os.date("*t")
		createWeekHour(date)
		func(date)
		interaction:reply("success")
	end)
	
end

do -- servers channel
	
	local url = require("url")
	
	benbebot:getCommand("1097727252168445952"):used({}, function(interaction, args)
		interaction:replyDeferred(true)

		local code = url.parse(args.invite or "").path:match("%w+$")
		if not code then interaction:reply("invalid invite url", true) return end

		local invite = benbebot:getInvite(code)
		if not invite then interaction:reply("invalid invite", true) return end
		
		if not interaction.member then return end
		if not interaction.member:hasRole("1068640885581025342") then
			
			if interaction.user ~= invite.inviter then interaction:reply("you cannot add an invite that you did not create", true) return end

			local bGuild = benbebot:getGuild(invite.guildId)
			local fGuild = familyGuy:getGuild(invite.guildId)
			if not (bGuild and bGuild.me or fGuild and fGuild.me) then interaction:reply("server does not have any benbebots", true) return end
			
		end
		
		interaction:reply("adding invite for " .. invite.guildName .. " to <#1089964247787786240>", true)
		benbebot:getChannel("1089964247787786240"):send("discord.gg/" .. invite.code)
		benbebot:info("added invite %s to servers channel", invite.code)
		
	end)
	
end

do -- game server
	
	local cmd = benbebot:getCommand("1097727252168445953")
	
	local http, json, querystring, uv, los, keyvalue = require("coro-http"), require("json"), require("querystring"), require("uv"), require("los"), require("key-value")
	
	local function steamRequest(method, interface, method2, version, parameters, ...)
		parameters = parameters or {}
		parameters.key = TOKENS.steamApi
		local res, body = http.request(method, string.format("https://api.steampowered.com/%s/%s/v%d/?%s", interface, method2, version, querystring.stringify(parameters)), ...)
		
		if res.code ~= 200 then return nil end
		
		return json.parse(body) or body
	end
	
	local collections
	
	local function scrapeCollection(id)
		local res, body = http.request("GET", "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. id)
		if res.code ~= 200 or not body then return nil, "could not fetch collections" end
		
		body = body:match("<div%s*class=\"workshopItemDescription\"%s*id=\"highlightContent\">(.-)</div>")
		if not body then return nil, "could not find item description" end
		
		body = querystring.urldecode(body)
		if not body then return nil, "could not decode description" end
		
		body = keyvalue.decode(body)
		if not body then return nil, "could not read keyvalue data" end
		
		return body
	end
	
	benbebot:on("ready", function()
		local tbl = {}
		local data, err = scrapeCollection("2966047786")
		if not data then benbebot:output("error", "garrysmod server: %s", err) return end
		for _,v in pairs(data.Collections) do
			local data, err = scrapeCollection(v)
			
			if not data then benbebot:output("error", "garrysmod server: %s", err) return end
			
			table.insert(tbl, data.Gamemode)
		end
		
		benbebot:info("Finished scraping gamemodes")
		
		collections = tbl
	end)
	
	local function getGSLT()
		local tokens = steamRequest("GET", "IGameServersService", "GetAccountList", 1)
		if type(tokens) ~= "table" then return nil, "failed to fetch game server account" end
		tokens = tokens.response
		
		if tokens.is_banned then return nil, "game server account has been banned" end
		
		local server
		for _,v in ipairs(tokens.servers) do
			if v.memo == "garrysmodserver" then
				server = v
				break
			end
		end
		if not server then return nil, "game server token does not exist" end
		
		return server
	end
	
	local srcdsPath, srcdsCwd
	if require("los").type() == "win32" then
		srcdsPath = require("path").join(uv.cwd(), "bin/SrcdsConRedirect.exe")
		srcdsCwd = "./garrysmodds/"
	else
		srcdsPath = "garrysmodds/srcds_run"
	end
	
	local garrysmodRunning = false
	
	cmd:used({"start"}, function(interaction, args)
		if not collections then interaction:reply("loading gamemode data, please try again later") return end
		if garrysmodRunning then interaction:reply("there is already a server instance running") return end
		interaction:replyDeferred()
		
		-- GSLT
		local gsltToken
		do
			local server, err = getGSLT()
			if not server then benbebot:error("Game server auth error: " .. err) interaction:reply("auth error: " .. err) return end
			if server.is_expired then
				steamRequest("POST", "IGameServersService", "ResetLoginToken", 1, {input_json = string.format("{\"steamid\":%s}", server.steamid)})
				server, err = getGSLT()
				if not server then benbebot:error("Game server auth error: " .. err) interaction:reply("auth error: " .. err) return end
				benbebot:info("Reset garrysmod game server token")
			end
			
			gsltToken = server.login_token
		end
		
		-- parse gamemode
		local gamemode
		args.gamemode = args.gamemode or "sandbox"
		if args.gamemode then
			for _,v in ipairs(collections) do
				local start, fin = string.find(v.title:lower(), args.gamemode:lower(), nil, true)
				if (start and fin) and start == 1 then
					gamemode = v
				end
			end
		end
		if not gamemode then interaction:reply("input error: invalid gamemode") return end
		
		-- parse map
		local map = args.map or gamemode.default_map or "gm_construct"
		if not map then interaction:reply("input error: invalid map") return end
		
		garrysmodRunning = true
		
		-- spawn srcds
		local stdin, stdout, stderr = uv.new_pipe() ,uv.new_pipe(), uv.new_pipe()
		
		local proc, procId = uv.spawn(srcdsPath, {
			args = {"+maxplayers", "32", "-console", "-p2p", "+host_workshop_collection", "0", "+gamemode", gamemode.gamemode, "+map", map, "+sv_setsteamaccount", gsltToken},
			stdio = {stdin, stdout, stderr},
			cwd = srcdsCwd,
			detached = true
		}, function()
			stdout:read_stop()
			benbebot:emit("gmodStop")
			garrysmodRunning = false
		end)
		if not proc then interaction:reply("spawn error: could not create server instance") return end
		
		interaction:reply({
			embed = {
				title = "Starting server ",
				description = "```\n```"
			}
		})
		local reply = interaction:getReply()
		
		-- handle output
		local outStr, updating = "", false
		local function updateReply()
			reply.embed.description = string.format("```\n%s\n```", outStr:match("([^\n\r]+)%s*$"))
			reply:setEmbed(reply.embed)
			updating = false
		end
		local function readStdout(err, chunk)
			if err or not chunk then return end
			local pre, post = chunk:match("^(.-)[\n\r]+(.-)$")
			if pre and post then
				table.insert(outStr, pre)
				benbebot:emit("gmodOutput", table.concat(outStr))
				outStr = {}
			end
			table.insert(outStr, post or chunk)
		end
		stdout:read_start(function(err, chunk)
			if err then return end
			if not chunk then return end
			
			outStr = outStr .. chunk -- would use a buffer but its probably not worth it
			
			local joinStr = outStr:match("%-+%s*Steam%s*P2P%s*%-+.-`(.-)`%s*%-+")
			if joinStr then
				stdout:read_stop()
				outStr = {}
				stdout:read_start(readStdout)
				benbebot:emit("gmodStart", joinStr)
				coroutine.wrap(function()
					reply:setEmbed({title = "Succesfully started Garrysmod server",description = "outputting into <#1068641386024407041>"})
				end)()
			elseif not updating then
				updating = true
				coroutine.wrap(updateReply)()
			end
		end)
	end)
	
	benbebot:on("gmodStart", function(joinStr)
		benbebot:getChannel("1068641386024407041"):send({content = "<@&1068664164786110554>", embed = {
			title = "A GarrysMod Server Has Started",
			description = string.format("you can join it by putting `%s` into your console, or by clicking steam://run/4000//%s/ to launch garrysmod and join", joinStr, querystring.urlencode("+" .. joinStr))
		}})
	end)
	benbebot:on("gmodStop", function()
		benbebot:getChannel("1068641386024407041"):send({embed = {description = "server has stopped"}})
	end)
	
	benbebot:on("gmodOutput", function(str)
		benbebot:getChannel("1068641386024407041"):send(str)
	end)
	
	cmd:used({"addon"}, function() end)
	
	local urlParse, http, ll, keyvalue, bit32 = require("url").parse, require("coro-http"), require("long-long"), require("key-value"), require("bit")
	
	local function parseId(str)
		local id = str:match("^/profiles/(%d+)") or str:match("^%s*(%d+)%s*$") -- SteamID64
		if id then
			return http.request("GET", string.format("https://steamcommunity.com/profiles/%s?xml=1", id))
		end
		
		id = str:upper():match("^%s*%[?(%a:1:%d+)%]?%s*$")  -- SteamID3
		if id then
			return http.request("GET", string.format("http://steamcommunity.com/profiles/[%s]?xml=1", id))
		end
		
		local id = str:upper():match("^%s*(STEAM_%d:%d:%d+)%s*$") -- SteamID
		if id then
			return nil
		end
		
		id = str:match("^/id/([^/]+)") or str  -- Vanity url
		if id then
			return http.request("GET", string.format("https://steamcommunity.com/id/%s?xml=1", id))
		end
	end
	
	local userPath = "./garrysmodds/garrysmod/settings/users.txt"
	
	cmd:used({"admin"}, function(interaction, args)
		interaction:replyDeferred()
		
		if not fs.existsSync(userPath) then interaction:reply("users.txt does not exist") return end
		
		local url = urlParse(args.url or "")
		
		if url.host and url.host ~= "steamcommunity.com" then interaction:reply("invalid site") return end
		
		local res, body = parseId(url.path)
		body = body or ""
		
		local id64 = body:match("<steamID64>(.-)</steamID64>")
		if not id64 then interaction:reply("could not locate steam account id on steam") return end
		
		id = ll.strtoull(id64)
		if not id then interaction:reply("could not read steamID64") return end
		
		id = string.format("STEAM_%s:%s:%s", 
			ll.tostring(bit32.rshift(bit32.band(id, 0xFF00000000000000ULL), 56)), 
			ll.tostring(bit32.band(id, 1ULL)), 
			ll.tostring(bit32.rshift(bit32.band(id, 0xFFFFFFFFULL), 1))
		)
		
		local name = body:match("<steamID><!%[CDATA%[(.-)%]%]></steamID>")
		
		local users = keyvalue.decode(fs.readFileSync(userPath)).Users
		
		if users.admin[id64] then interaction:reply("this account is already an admin") return end
		users.admin = users.admin or {}
		users.admin[id64] = id
		
		fs.writeFileSync(userPath, keyvalue.encode({Users = users}))
		
		local image = body:match("<avatarIcon><!%[CDATA%[(.-)%]%]></avatarIcon>")
		
		local desc = string.format("added %s (`%s`) to admin perms", name or "unknown", id)
		
		interaction:reply({
			embed = {
				description = desc,
				thumbnail = image and {url = image}
			}
		})
		
		benbebot:info(string.format("added %s (%s) to gmod admin perms", name or "unknown", id))
	end)
	
end

do -- get files --
	local fs, appdata, watcher, path = require("fs"), require("data"), require("fs-watcher"), require("path")
	
	local cmd = benbebot:getCommand("1100968409765777479")
	
	local fileLocations = {}
	local paths = {}
	
	local function processFile(loc, event, filepath, newpath)
		if event == "delete" or event == "rename" then
			for i,v in ipairs(fileLocations[loc]) do
				if path.pathEquals(v, filepath) then table.remove(fileLocations[loc], i) break end
			end
		end
		
		if event == "create" or event == "rename" then
			local filepath = (newpath or filepath):gsub("\\", "/")
			
			table.insert(fileLocations[loc], filepath)
		end
		
		if event == "error" then
			error(filepath or "")
		end
	end
	
	local function scanFiles(loc, pa)
		if not fs.existsSync(pa) then return end
		local iter = fs.scandirSync(pa)
		
		local map = {iter = iter, p = ""}
		
		local file, t = iter()
		while map and file do
			if t == "directory" then
				iter = fs.scandirSync(path.join(pa, map.p, file))
				map = {iter = iter, parent = map, p = path.join(map.p, file)}
			else
				local pat = path.join(map.p, file):gsub("\\", "/")
				table.insert(fileLocations[loc], pat)
			end
			
			file, t = iter()
			if not file then
				map = map.parent
				if map then
					iter = map.iter
					file, t = iter()
				end
			end
		end
	end
	
	fileLocations.appdata = {}
	paths.appdata = appdata.path("")
	
	scanFiles("appdata", paths.appdata)
	watcher.watch(paths.appdata, true, function(...) processFile("appdata", ...) end)
	
	fileLocations.temp = {}
	paths.temp = appdata.tempPath("")
	
	scanFiles("temp", paths.temp)
	watcher.watch(paths.temp, true, function(...) processFile("temp", ...) end)
	
	fileLocations.garrysmod = {}
	paths.garrysmod = "./garrysmodds/garrysmod/data/"
	
	scanFiles("garrysmod", paths.garrysmod)
	watcher.watch(paths.garrysmod, true, function(...) processFile("garrysmod", ...) end)
	
	scanFiles = nil
	
	cmd:autocomplete({}, function(interaction, args, _, focused)
		if not (args.location and args.path) then return {} end
		if not interaction.member:hasRole("1068640885581025342") then return {} end
		if focused ~= "path" then return {} end 
		local files = fileLocations[args.location or ""]
		if not files then return {} end
		
		local autocomplete, n = {}, 0
		
		for _,path in ipairs(files) do
			local start = string.find(path, args.path, nil, true)
			if start and start <= 1 then
				n = n + 1
				table.insert(autocomplete, {name = path, value = path})
			end
			if n >= 25 then break end 
		end
		
		return autocomplete
	end)
	
	cmd:used({}, function(interaction, args)
		if not interaction.member:hasRole("1068640885581025342") then interaction:reply("you are not authorized to use this command", true) return end
		if not (args.location and args.path) then interaction:reply("please provide all arguments", true) return end
		
		local pa = paths[args.location]
		if not pa then interaction:reply("location is invalid", true) return end
		pa = path.join(pa, args.path)
		if not fs.existsSync(pa) then interaction:reply("path is invalid", true) return end
		
		local content = fs.readFileSync(pa)
		if not content then interaction:reply("file is invalid", true) return end
		
		interaction:reply({file = {path.basename(pa), content}}, true)
	end)
end

do -- bot control --
	local uv, jit, los = require("uv"), require("jit"), require("los")
	local spawn = require("coro-spawn")
	
	local cmd = benbebot:getCommand("1101705431769948180")
	
	cmd:used({"version"}, function(interaction)
		-- git version
		local proc, err = spawn("git", {args = {"rev-parse", "--short", "HEAD"}, stdio = {nil, true}})
		if not proc then return end
		proc:waitExit()
		
		local gitHash = proc.stdout.read()
		
		interaction:reply({embed = {
			description = string.format("Luvit %s\n%s\nBenbebots %s `%s`\n%s_%s%s", uv.version_string(), jit.version, VERSION, gitHash, jit.os, jit.arch, los.isProduction() and "" or " Test Branch")
		}})
	end)
	
	cmd:used({"pull"}, function(interaction)
		if not los.isProduction() then interaction:reply("cannot pull on test branch") return end
		
		local proc, err = spawn("git", {args = {"pull"}, stdio = {nil, true, true}})
		if not proc then return end
		proc:waitExit()
		
		interaction:reply({embed = {
			description = string.format("```%s```", proc.stdout.read() or proc.stderr.read())
		}})
		
		os.exit()
	end)
	
	cmd:used({"restart"}, function(interaction)
		interaction:reply("restarting...")
		os.exit()
	end)
	
end

do -- get invite --
	
	benbebot:getCommand("1106752557956726855"):used({}, function(interaction, args)
		local user = benbebot:getUser(args.bot)
		if not user then interaction:reply("error") return end
		if not user.bot then interaction:reply("not a bot") return end
		
		interaction:reply(string.format("https://discord.com/api/oauth2/authorize?client_id=%s&permissions=0&scope=bot", user.id), true)
	end)
	
end

-- CANNED FOOD --

do -- nothing wacky here
	local emoji, timer = require("querystring").urldecode("%F0%9F%A5%AB"), require("timer")
	
	local channels
	
	if require("los").isProduction() then
		channels = {
			"860934345677864961", -- swiss sauce annoucements
			"1036666698746581024", -- smoke annoucements
			--"823397621887926272", "822165179692220479", -- breadbag
			"670393873813733416", -- pro promello
			"884714408922742784", -- librarian
			"564829092621451274", -- alphaplace
			"750840603113422889", -- gabe
			"1020127285229146112" -- ghetto smosh
		}
	else
		channels = {
			TEST_CHANNEL -- test channel
		}
	end
	
	local function checkChannel(id)
		local rightChannel = false
		for _,channel in ipairs(channels) do
			if id == channel then rightChannel = true break end
		end
		return rightChannel
	end
	
	cannedFood:on("messageCreate", function(message)
		if not checkChannel(message.channel.id) then
			local rightUser = false
			for user in message.mentionedUsers:iter() do
				if user.id == cannedFood.user.id then rightUser = true break end
			end
			if not rightUser then return end
		end
		local delay = math.random(1,12000)
		timer.sleep(delay)
		message:addReaction(emoji)
		cannedFood:info("Reacted to message in %s with a delay of %ds", message.guild.name, delay / 1000)
	end)
end

-- OTHER --

do -- remote manage server
	local http, fs, url = require("coro-http"), require("fs"), require("url")
	
	local fileToWrite = require("los").isProduction() and ".tokens" or "alternate.tokens"
	
	privateServer:on("/token/upload", function(res, body)
		if (res.query or {}).pass ~= TOKENS.serverAuth then return {code = 401}, "Unauthorized" end
	
		local res = {fs.writeFileSync(fileToWrite, body)}
		return nil, body
	end, {method = "POST"})
	
end

do -- events
	
	local json = require("json")
	
	local eventFile = appdata.path("events.json")
	local events = json.parse(fs.readFileSync(eventFile) or "{}") or {}
	-- {owner, masterMessage, message, isActive, channel}
	
	local function saveEvents()
		fs.writeFileSync(eventFile, json.stringify(events or {}))
	end
	
	local function formatMessage(pattern, message, url)
		return pattern:gsub("%${message}", tostring(message)):gsub("%${url}", "https://youtube.com/watch?v=" .. tostring(url))
	end
	
	publicServer:on("/notifs/youtube", function(req, body)
		
		local event = events[req.query.user]
		if not event then return false, "Non existant user" end
		
		local id = (body or ""):match("<yt:videoId>(.-)</yt:videoId>")
		if not id then return false, "Couldnt parse video id" end
		
		benbebot:getChannel(event[5]):send(formatMessage(event[2], event[3], href))
		
	end)
	
	local function acId(interaction, args, _, focused)
		if focused ~= "id" then return end
		
		local isAdmin = benbebot:getGuild(BOT_GUILD):getMember(interaction.user.id):hasRole("1068640885581025342")
		
		local ids = {}
		for i,v in pairs(events) do
			if isAdmin or v[1] == interaction.user.id then
				table.insert(ids, {name = i, value = i})
			end
		end
		
		return ids
	end
	
	local cmd = benbebot:getCommand("1107064787294236803")
	
	local changedPattern = "changed %s from `%s` to `%s`"
	local messagePattern = "%s\n\nthis will look like:\n%s"
	
	cmd:autocomplete({"master"}, acId)
	cmd:used({"master"}, function(interaction, args)
		local beforeValue = events[args.id][2]
		events[args.id][2] = args.message or json.null
		saveEvents()
		
		interaction:reply(messagePattern:format(changedPattern:format("master message", tostring(beforeValue), tostring(events[args.id][2])), formatMessage(events[args.id][2], events[args.id][3], "blablabla")))
	end)
	
	cmd:autocomplete({"message"}, acId)
	cmd:used({"message"}, function(interaction, args)
		local beforeValue = events[args.id][3]
		events[args.id][3] = args.message or json.null
		saveEvents()
		
		interaction:reply(messagePattern:format(changedPattern:format("message", tostring(beforeValue), tostring(events[args.id][3])), formatMessage(events[args.id][2], events[args.id][3], "blablabla")))
	end)
	
	cmd:autocomplete({"active"}, acId)
	cmd:used({"active"}, function(interaction, args)
		local beforeValue = events[args.id][4]
		events[args.id][4] = args.active or json.null
		saveEvents()
		
		interaction:reply(changedPattern:format("active", tostring(beforeValue, tostring(events[args.id][4])))
	end)
	
	cmd:autocomplete({"channel"}, acId)
	cmd:used({"channel"}, function(interaction, args)
		if not (args.channel or args.channelid) then interaction:reply("please specify a channel") return end
		local beforeValue = events[args.id][5]
		events[args.id][5] = args.channel or args.channelid or json.null
		saveEvents()
		
		interaction:reply(changedPattern:format("channel", tostring(beforeValue), tostring(events[args.id][5])))
	end)
	
	cmd:used({"new"}, function(interaction, args)
		if not benbebot:getGuild(BOT_GUILD):getMember(interaction.user.id):hasRole("1068640885581025342") then interaction:reply("you must be a bot admin to use this sub command") return end
		if events[args.id] then interaction:reply("event id already exists") return end
		events[args.id] = {args.owner or json.null, args.master or json.null, args.message or json.null, args.active or json.null, args.channel or json.null}
		saveEvents()
		
		interaction:reply("succesfully created event: " .. args.id)
	end)
	
end

do -- get cannedFood token
	local http, json = require("coro-http"), require("json")
	
	local res, body = http.request("POST", "https://discord.com/api/v9/auth/login", {{"content-type", "application/json"}}, json.stringify({
		captcha_key = json.null,
		login = TOKENS.cannedFoodEmail,
		password = TOKENS.cannedFoodPassword,
		undelete = false
	}))
	
	if res.code ~= 200 then cannedFood:error("could not scrape token: %s", body) end
	
	TOKENS.cannedFood = json.parse(body).token
end

local readys, thread = 0, coroutine.running()
local function func() readys = readys + 1 coroutine.resume(thread) end

benbebot:run("Bot " .. TOKENS.benbebot) benbebot:onceSync("ready", func)
familyGuy:run("Bot " .. TOKENS.familyGuy) familyGuy:onceSync("ready", func)
cannedFood:run(TOKENS.cannedFood) cannedFood:onceSync("ready", func)

repeat coroutine.yield() until readys >= 3

benbebot:info("All bots ready")

local success1, err1 = privateServer:start()
local success2, err2 = publicServer:start()

if not (success1 and success2) then
	benbebot:error("Failed to start TCP server(s)")
	print(err1)
	print(err2)
else
	benbebot:info("TCP servers started")
end

clock:start()