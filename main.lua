VERSION = "3.78"

local uv, fs, appdata, server, los = require("uv"), require("fs"), require("directory"), require("server"), require("los")

require("./load-deps.lua")

local discordia = require("discordia")
local enums = discordia.enums
local clock = discordia.Clock()

local logLevel = los.isProduction() and 3 or 4
fs.mkdirSync(appdata.path("logs"))
local benbebot = discordia.Client({logFile=appdata.path("logs/bbb_discordia.log"),gatewayFile=appdata.path("logs/bbb_gateway.json"),logLevel=logLevel})
local familyGuy = discordia.Client({logFile=appdata.path("logs/fg_discordia.log"),gatewayFile=appdata.path("logs/fg_gateway.json"),logLevel=logLevel,cacheAllMembers=true})
local cannedFood = discordia.Client({logFile=appdata.path("logs/cf_discordia.log"),gatewayFile=appdata.path("logs/cf_gateway.json"),logLevel=logLevel})
local uncannyCat = discordia.Client({logFile=appdata.path("logs/uc_discordia.log"),gatewayFile=appdata.path("logs/uc_gateway.json"),logLevel=logLevel,cacheAllMembers=true})
local fnafBot = discordia.Client({logFile=appdata.path("logs/fn_discordia.log"),gatewayFile=appdata.path("logs/fn_gateway.json"),logLevel=logLevel})
local genericLogger = discordia.Client()
benbebot._logger:setPrefix("BBB") familyGuy._logger:setPrefix("FLG") cannedFood._logger:setPrefix("CNF") uncannyCat._logger:setPrefix("UCC") genericLogger._logger:setPrefix("   ")
benbebot._logChannel, familyGuy._logChannel, cannedFood._logChannel, uncannyCat._logChannel = "1091403807973441597", "1091403807973441597", "1091403807973441597", "1091403807973441597"
benbebot:enableIntents(discordia.enums.gatewayIntent.guildMembers) familyGuy:enableIntents(discordia.enums.gatewayIntent.guildMembers) uncannyCat:enableIntents(discordia.enums.gatewayIntent.guildMembers)
local stats = require("stats")
local benbebotStats, familyGuyStats, cannedFoodStats, uncannyStats, fnafStats = stats(benbebot, "1068663730759536670"), stats(benbebot, "1068675455022026873"), stats(benbebot, "1112221100273848380"), stats(benbebot, "1124878312943124531"), stats(benbebot, "1126386629343461438")
local portAdd = los.isProduction() and 0 or 1
local privateServer = server.new("0.0.0.0", 26420 + portAdd)
local publicServer = privateServer:new(26430 + portAdd)

local exaroton = require("exaroton")

local exarotonClient = exaroton.client.new("Bearer " .. TOKENS.exaroton)

benbebot:defaultCommandCallback(function(interaction)
	interaction:reply({embed = {
		description = "couldnt find command, [please report this error](https://github.com/Benbebop/benbebots/issues)"
	}})
end)

local BOT_GUILD = "1068640496139915345"
local TEST_CHANNEL = "1068657073321169067"

local function reseedRandom()
	local seed = require("uv").gettimeofday()
	math.randomseed(seed)

	genericLogger:info("Seeded random (%d)", seed)
end

-- BREAD BAG --

do -- ping --
	
	benbebot:getCommand("1128437755614081052"):used({}, function(interaction)
		interaction:reply("<@463065400960221204>")
	end)
	
end

-- SMOKE SERVER --

local SMOKE_SERVER = "1036666698104832021"

do -- non alien role --
	
	benbebot:on("memberJoin", function(member)
		if member.guild.id ~= SMOKE_SERVER then return end
		
		local success, err = member:addRole("1037126896506392746")
		
		if not success then
			benbebot:outputNoPrint("error", "failed to add `Non Alien` role to new member:\n%s", err)
		end
	end)
	
end

-- BENBEBOTS SERVER --
	
do -- log dms
	
	local http = require("coro-http")
	
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
	
	familyGuy:getCommand("1125992663582257243"):used({}, function(interaction, args)
		local res, content
		if args.attachment then
			res, content = http.request("GET", args.attachment.url)
			if res.code < 200 or res.code >= 300 or not content then interaction:reply("error fetching data") return end
		end
		
		familyGuy:getUser(interaction.channel.topic):send({
			content = args.message,
			file = args.attachment and {args.attachment.filename, content}
		})
		interaction:reply(args.message)
	end)
	
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
	
	local json, http, los, urlParse, path, querystring = require("json"), require("coro-http"), require("los"), require("url").parse, require("path"), require("querystring")
	
	local SEND_CHANNEL = los.isProduction() and"1096581265932701827" or TEST_CHANNEL
	local STATION = "https://soundcloud.com/discover/sets/weekly::%s"
	local TRACK = "https://api-v2.soundcloud.com/tracks?ids=%s&client_id=%s"
	
	local function createWeekHour(date)
		date.whour = date.wday--(date.wday - 1) * 24 + date.hour
	end
	
	local MOTD_QUEUE = appdata.path("motd-queue.db")
	
	local function func(date)
		
		-- queue
		
		local fd = fs.openSync(MOTD_QUEUE, "r+")
		local cursor = fs.fstatSync(fd).size
		
		if cursor > 0 then
			cursor = cursor - 1
			local size = string.unpack(">I1", fs.readSync(fd, 1, cursor))
			cursor = cursor - size
			local uri = fs.readSync(fd, size, cursor)
			assert(fs.ftruncateSync(fd, cursor))
			fs.closeSync(fd)
			local url = "https://soundcloud.com/" .. uri
			
			local message = benbebot:getChannel(SEND_CHANNEL):send(url)
			benbebot:output("info", "sent queued mashup of the day")
			
			if los.isProduction() then benbebotStats.Soundclowns = (benbebotStats.Soundclowns or 0) + 1 end
			
			message:publish()
			
			return
		end
		
		fs.closeSync(fd)
		
		-- ask soundcloud instead
		
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
		if not stationTracks[index] then benbebot:output("error", "Could not index station track: %s", index) end
		local res, body = http.request("GET", string.format(TRACK, stationTracks[index].id, client_id))
		if not (res and (res.code == 200) and body) then benbebot:output("error", "failed to get soundcloud track: %s", res.reason or tostring(res.code)) return end
		
		local trackData = (json.parse(body) or {})[1]
		if not (trackData and trackData.permalink_url) then benbebot:output("error", "soundcloud station: track content is not valid") return end
		
		benbebot:getChannel(los.isProduction() and "1096581265932701827" or TEST_CHANNEL):send(trackData.permalink_url)
		benbebot:output("info", "sent mashup of the day: %s (index %d)", trackData.title, index)
		
		benbebotStats.Soundclowns = (benbebotStats.Soundclowns or 0) + 1
		
	end
	
	clock:on("wday", function(date)
		createWeekHour(date)
		func(date)
	end)
	
	local cmd = benbebot:getCommand("1103908487278379110")
	
	cmd:used({"force"}, function(interaction, args)
		local date = os.date("*t")
		createWeekHour(date)
		func(date)
		interaction:reply("success")
	end)
	
	local function getUri(url)
		local url = urlParse(url or "")
		
		local uri
		if url.host == "soundcloud.com" then
			uri = url.pathname
		elseif url.host == "on.soundcloud.com" then
			local res = http.request("GET", "https://on.soundcloud.com" .. url.pathname, nil, nil, {followRedirects = false})
			if res.code ~= 302 then return nil, "invalid redirect" end
			url = nil
			for _,v in ipairs(res) do
				if v[1] == "Location" then
					url = urlParse(v[2])
				end
			end
			if (not url) or url.host ~= "soundcloud.com" then return nil, "could not find location" end
			uri = url.pathname
		elseif not url.host then
			uri = url.path
		else
			return nil, "invalid url"
		end
		
		return uri:gsub("^[/\\]", "")
	end
	
	cmd:used({"queue"}, function(interaction, args)
		interaction:replyDeferred()
		local uri, err = getUri(args.url)
		
		if not uri then interaction:reply(err) return end
		
		fs.appendFileSync(MOTD_QUEUE, uri .. string.pack(">I1", #uri))
		
		interaction:reply("added `" .. uri .. "` to queue")
	end)
	
	cmd:used({"check"}, function(interaction, args)
		interaction:replyDeferred()
		local uri, err = getUri(args.url)
		
		if not uri then interaction:reply(err) return end
		
		local fd = fs.openSync(MOTD_QUEUE, "r")
		local cursor = fs.fstatSync(fd).size
		
		local exists = false
		while cursor > 0 do
			cursor = cursor - 1
			local size = string.unpack(">I1", fs.readSync(fd, 1, cursor))
			cursor = cursor - size
			local compUri = fs.readSync(fd, size, cursor)
			
			if uri == compUri then
				exists = true
				break
			end
		end
		
		fs.closeSync(fd)
		
		if (not exists) and (args.search == nil or args.search) then
			local params = {channel_id = "1096581265932701827", author_id = "941372431082348544", content = "https://soundcloud.com/" .. uri}
			local res = cannedFood._api:request("GET", ("/guilds/%s/messages/search?%s"):format("1068640496139915345", querystring.stringify(params)))
			
			if (res.total_results or 0) >= 1 then
				exists = true
			end
		end
		
		if exists then
			interaction:reply("found track: " .. uri)
		else
			interaction:reply("did not find track: " .. uri)
		end
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

local GARRYSMOD_DIR
do -- game server
	
	local cmd = benbebot:getCommand("1097727252168445953")
	
	do -- garrys mod
		
		local http, json, querystring, uv, los, keyvalue, timer, steamworks = require("coro-http"), require("json"), require("querystring"), require("uv"), require("los"), require("source-engine/key-value"), require("timer"), nil
		
		local function steamRequest(method, interface, method2, version, parameters, ...)
			parameters = parameters or {}
			parameters.key = TOKENS.steamApi
			local res, body = http.request(method, string.format("https://api.steampowered.com/%s/%s/v%d/?%s", interface, method2, version, querystring.stringify(parameters)), ...)
			
			if res.code ~= 200 then return nil end
			
			return json.parse(body) or body
		end
		
		-- retrieve collection data
		
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
		
		-- get executable
		
		local pathJoin = require("path").join
		
		local STEAM_DIR = los.type() == "win32" and "C:/Program Files (x86)/Steam" or "~/.steam/steam"
		
		local libraryfolders = keyvalue.decode(assert(fs.readFileSync(pathJoin(STEAM_DIR, "steamapps/libraryfolders.vdf")))).libraryfolders
		local installindex = "0"
		for i,v in pairs(libraryfolders) do
			for l in pairs(v.apps) do
				if l == "4020" then installindex = i end
			end
		end
		local installpath = libraryfolders[installindex].path
		
		local manifestFile = pathJoin(installpath, "steamapps/appmanifest_4020.acf")
		if fs.existsSync(manifestFile) then
			local manifest = keyvalue.decode(fs.readFileSync(manifestFile)).AppState
			GARRYSMOD_DIR = pathJoin(installpath, "steamapps/common", manifest.installdir)
		else
			GARRYSMOD_DIR = pathJoin(installpath, "steamapps/common/GarrysModDS")
		end
		
		-- start server
		
		local GARRYSMOD_CHANNEL = "1068641386024407041"
		
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
		
		local function addArg(tbl, part1, part2)
			table.insert(tbl,tostring(part1)) table.insert(tbl,tostring(part2))
		end
		
		local function truncateLines(str, count)
			local lines, l = {}, 0
			for line in str:gmatch("[^\n\r]+") do
				table.insert(lines, line)
				l = l + 1
				if l > count then
					table.remove(lines, 1)
				end
			end
			return table.concat(lines, "\n")
		end
		
		local gmod = discordia.Emitter()
		
		local gmodActive, gmodReady = false, false
		local gmodInitReply
		
		local mapCache = {}
		local function cacheMaps(collectionId)
			local dir = pathJoin(GARRYSMOD_DIR, "garrysmod/data", collectionId, "maps.json")
			if not fs.existsSync(dir) then return end
			mapCache[collectionId] = json.parse(fs.readFileSync(dir))
			table.sort(mapCache[collectionId]) 
			return true
		end
		
		cmd:used({"gmod","collection"}, function(interaction, args)
			
		end)
		
		cmd:used({"gmod","addon"}, function(interaction, args)
			
		end)
		
		cmd:autocomplete({"gmod","start"}, function(interaction, args, _, focused)
			if focused ~= "map" then return end
			
			
		end)
		
		cmd:used({"gmod","start"}, function(interaction, args)
			if gmodActive then interaction:reply("server is already in progress", true) return end
			gmodActive = true
			
			interaction:replyDeferred()
			
			-- collection
			
			local collection
			
			
			
			-- initialise autogenerated lua files
			
			do
				local addonDir = pathJoin(GARRYSMOD_DIR, "garrysmod/addons") fs.mkdirSync(addonDir)
				addonDir = pathJoin(addonDir, "autogen") fs.mkdirSync(addonDir)
				
				local luaDir = pathJoin(addonDir, "lua") fs.mkdirSync(autorun)
				local autorunDir = pathJoin(luaDir, "autorun") fs.mkdirSync(autorunDir)
				
				fs.writeFileSync(pathJoin(autorunDir, "createResourceList.lua"), string.format(fs.readFileSync("resource/garrysmod/createResourceList.lua"), os.time(), tostring(collection.id)))
			end
			
			-- create args
			
			local args = {"-console", "-p2p"}
			addArg(args, "+maxplayers", 32)
			addArg(args, "+gamemod", "sandbox")
			addArg(args, "+map", "gm_construct")
			
			local gslt, err = getGSLT()
			if gslt then
				addArg(args, "+sv_setsteamaccount", gslt.login_token)
			else benbebot:output("warning", "could not get gslt: %s", err) end
			
			-- spawn srcds process
			
			local stdio = {nil, uv.new_pipe(), uv.new_pipe()}
			
			local onExit = function() end
			gmodActive = assert(uv.spawn(pathJoin(uv.cwd(), "bin/SrcdsConRedirect.exe"), {
				args = args,
				stdio = stdio,
				cwd = GARRYSMOD_DIR
			}, function(...)
				gmodActive = false
				onExit(...)
			end))
			
			-- setup stdio
			
			local embedScheme = {
				title = "starting server",
				description = "```\n```"
			}
			
			local obuffer, ebuffer = {}, {}
			local modified = false
			
			stdio[2]:read_start(function(err, data) -- out
				if err then table.insert(ebuffer, err) return end
				if not data then return end
				table.insert(obuffer, data)
				modified = true
			end)
			
			stdio[3]:read_start(function() -- err
				if err then table.insert(ebuffer, err) return end
				if not data then return end
				table.insert(ebuffer, data)
				modified = true
			end)
			
			interaction:reply({embed = embedScheme})
			gmodInitReply = interaction:getReply()
			
			-- wait for p2p id
			
			local p2pJoinCommand
			repeat
				if modified then
					local str = table.concat(obuffer)
					p2pJoinCommand = str:match("%-+%sSteam%sP2P%s%-+.-`([^`]+).-%-+")
					if p2pJoinCommand then break end
					
					embedScheme.description = string.format("```\n%s\n```", truncateLines(str, 7))
					modified = false
					gmodInitReply:setEmbed(embedScheme)
				else
					timer.sleep(1000)
				end
			until not gmodActive
			if not p2pJoinCommand then gmodInitReply:update({content = "server closed while starting"}) return end
			
			local message = benbebot:getChannel(GARRYSMOD_CHANNEL):send({embed = {
				title = "gmod server is online",
				description = string.format("join with the console command `%s`", p2pJoinCommand)
			}})
			gmodInitReply:setEmbed({description = string.format("started server at p2p:%s\n\n%s", p2pJoinCommand:match("p2p:(%d+)"), message.link)})
			
			stdio[2]:read_stop()
			obuffer = ""
			stdio[2]:read_start(function(err, data)
				if err then table.insert(ebuffer, err) return end
				if not data then return end
				obuffer = obuffer .. data
				
				local success = false
				for line in obuffer:gmatch("([^\n\r]+)[\n\r]+") do
					success = true
					gmod:emit("raw", line)
				end
				if success then obuffer = "" end
			end)
			
			gmod:emit("ready", p2pJoinCommand, nil, message)
			onExit = function(...)
				gmod:emit("stop", table.concat(ebuffer), ...)
			end
		end)
		
		cmd:used({"gmod","stop"}, function(interaction)
			if type(gmodActive) ~= "userdata" then interaction:reply("server must be online first") return end
			local success, err = gmodActive:kill()
			if not success then interaction:reply(err) return end
			interaction:reply("successfully killed server instance")
		end)
		
		-- admin stuff
		
		local urlParse, http, ll, keyvalue, bit32 = require("url").parse, require("coro-http"), require("long-long"), require("source-engine/key-value"), require("bit")
		
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
		
		local USERS = pathJoin(GARRYSMOD_DIR, "garrysmod/settings/users.txt")
		
		cmd:used({"gmod","admin"}, function(interaction, args)
			interaction:replyDeferred()
			
			if not fs.existsSync(USERS) then interaction:reply("users.txt does not exist") return end
			
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
			
			local users = keyvalue.decode(fs.readFileSync(USERS)).Users
			
			if users.admin[id64] then interaction:reply("this account is already an admin") return end
			users.admin = users.admin or {}
			users.admin[id64] = id
			
			fs.writeFileSync(USERS, keyvalue.encode({Users = users}))
			
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
		
		-- update
		
		local updateActive
		
		--[[cmd:used({"gmod","update"}, function(interaction)
			if updateActive then interaction:reply("already updating :)", true) return end
			updateActive = true
			
			local thread = coroutine.running()
			
			local stdio = {nil, uv.new_pipe(), uv.new_pipe()}
			updateActive = assert(uv.spawn(pathJoin(STEAM_DIR, "steamcmd.exe"), {
				args = {
					"+login", "anonymous",
					"+app_update", "4020", "validate",
					"+quit"
				}, stdio = stdio
			}, function(...)
				coroutine.resume(thread)
			end))
			
			local buffer = ""
			
			local func()
				if err then table.insert(buffer, err) return end
				if not data then return end
				buffer = buffer .. data
				
				
			end
			
			stdio[2]:read_start(func)
			stdio[3]:read_start(func)
			
			coroutine.yield()
			
			gmodActive = false
			
		end)]]
		
		-- server events
		
		gmod:on("ready", function(joinStr, options)
			benbebot:getChannel(GARRYSMOD_CHANNEL):setTopic("ONLINE")
		end)
		
		gmod:on("stop", function()
			local channel = benbebot:getChannel(GARRYSMOD_CHANNEL)
			channel:send({embed = {description = "server stopped"}})
			channel:setTopic()
		end)
		
		gmod:on("raw", function(line)
			benbebot:getChannel(GARRYSMOD_CHANNEL):send(line)
		end)
		
	end
	
	do -- minecraft
		
		local nbt, json, miniz, https, url = require("nbt"), require("json"), require("miniz"), require("https"), require("url")
		
		local server = exarotonClient:getServer("mPDAx5chPlm8yrts")
		
		benbebot:on("ready", function()
			--server.websocket:connect()
		end)
		
		local util = require("util")
		
		local SAVE_SUBDIR = server.id or "undef"
		local SAVE_DIR = appdata.path("game-backups", "minecraft", SAVE_SUBDIR)
		fs.mkdirSync(appdata.path("game-backups")) fs.mkdirSync(appdata.path("game-backups", "minecraft")) fs.mkdirSync(appdata.path("game-backups", "minecraft", SAVE_SUBDIR))
		
		cmd:used({"minecraft","start"}, function(interaction)
			if not (interaction.member:hasRole("1111726132660813886") or interaction.user.id == "565367805160062996") then interaction:reply("this command is restricted", true) return end
			interaction:replyDeferred(true)
			local success, err = server:start()
			if not success then interaction:reply(err, true) return end
			interaction:reply("starting server", true)
		end)
		
		cmd:used({"minecraft","stop"}, function(interaction)
			interaction:replyDeferred(true)
			local success, err = server:stop()
			if not success then interaction:reply(err, true) return end
			interaction:reply("stopping server", true)
		end)
		
		local MAP_COLORS = json.parse(fs.readFileSync("resource/minecraft/map-colors.json"))
		local MAP_COLORS_VERSION, MAP_COLORS = MAP_COLORS.version, MAP_COLORS.data
		
		cmd:used({"minecraft","createmap"}, function(interaction, args)
			local source = args.image
			local fCat, fType = source.content_type:match("^(.-)/(.-)$")
			if fCat ~= "image" then interaction:reply("file must be an image", true) return end
			
			interaction:replyDeferred()
			
			local stdin, stdout, stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
			
			local colorBytes, n = {}, 0
			local buffer = {}
			local mainThread, procThread = coroutine.running(), coroutine.create(function(exit)
				if exit then return end
				repeat
					local data = table.concat(buffer)
					buffer = {}
					
					local cursor, packet = 1, data:sub(1,4)
					while #packet >= 4 do
						local r,g,b,a = string.unpack(">I1>I1>I1>I1", packet)
						
						if a <= 0 then -- pixel is transparent
							table.insert(colorBytes, 0) n = n + 1
						else
							local minDist, minIndex = math.huge, nil
							for i,v in pairs(MAP_COLORS) do
								if v[1] then
									local distSqr = (v[1] - r) ^ 2 + (v[2] - g) ^ 2 + (v[3] - b) ^ 2
									if minDist >= distSqr then
										minDist, minIndex = distSqr, i
									end
									if distSqr <= 0 then break end
								end
							end
							
							table.insert(colorBytes, tonumber(minIndex)) n = n + 1
						end
						
						cursor = cursor + 4
						if #buffer > 0 then -- shouldnt ever happen but just in case
							data = data .. table.concat(buffer)
							buffer = {}
						end
						packet = data:sub(cursor, cursor + 3)
					end
					
					buffer = {packet}
				until (n >= 16384) or coroutine.yield()
			end)
			
			local errBuffer = {}
			assert(uv.spawn("bin/ffmpeg", {
				stdio = {stdin, stdout, stderr},
				args = {
					"-hide_banner", "-loglevel", "error",
					"-i", "-", -- in args
					"-f", "rawvideo", "-pix_fmt", "rgba", "-s", "128x128", "-" -- out args
				}
			},function()
				coroutine.resume(procThread, true)
				coroutine.resume(mainThread)
				stdout:close()
				stderr:close()
			end))
			
			stdout:read_start(function(err, data)
				assert(not err, err)
				if not data then return end
				
				table.insert(buffer, data)
				
				if coroutine.status(procThread) ~= "suspended" then return end
				assert(coroutine.resume(procThread))
			end)
			
			stderr:read_start(function(err, data)
				assert(not err, err)
				if not data then return end
				
				table.insert(errBuffer, data)
			end)
			
			local req = url.parse(source.url)
			req.method = "GET"
			
			assert(https.request(req, function(res)
				res:on("data", function(chunk) stdin:write(chunk) end)
				res:on("end", function(chunk) stdin:close() end)
			end)):done()
			
			coroutine.yield()
			
			local mapData = miniz.compress(nbt.newCompound({
				data = nbt.newCompound({
					scale = nbt.newByte(0),
					dimension = nbt.newString(""),
					trackingPosition = nbt.newByte(0),
					unlimitedTracking = nbt.newByte(0),
					locked = nbt.newByte(1),
					xCenter = nbt.newInt(0),
					yCenter = nbt.newInt(0),
					banners = nbt.newList(nbt.TAG_COMPOUND, {}),
					frames = nbt.newList(nbt.TAG_COMPOUND, {}),
					colors = nbt.newByteArray(colorBytes)
				}),
				DataVersion = nbt.newInt(MAP_COLORS_VERSION)
			}):encode())
			
			interaction:reply({file = {"map.dat", mapData}})
			
		end)
		
		cmd:used({"minecraft","getmap"}, function(interaction)
			
		end)
		
		local function saveWorld()
			local world = server:getFile("world")
		end
		
		cmd:used({"minecraft","backup"}, function(interaction)
			local success, err = saveWorld()
			if success then interaction:reply("saved world")
			else interaction:reply(err)
			end
		end)
		
		cmd:used({"minecraft","backupstatus"}, function(interaction)
			interaction:replyDeferred()
			local earliest, latest, latestData, count, size = util.nearHuge, -util.nearHuge, nil, 0, 0
			for f,t in fs.scandirSync(SAVE_DIR) do
				if t == "file" then
					local stats = fs.statSync(SAVE_DIR .. "/" .. f)
					if stats then
						count = count + 1
						size = size + stats.size
						earliest, latest = math.min(earliest, stats.birthtime.sec), math.max(latest, stats.birthtime.sec)
					end
				end
			end
			
			interaction:reply({embed = {
				description = ("save info for %s (%s)"):format(SAVE_SUBDIR, server.name or "undef"),
				fields = {
					{name = "#", value = count, inline = true},
					{name = "Earliest", value = util.createTimestamp("sdt", earliest), inline = true},
					{name = "Latest", value = util.createTimestamp("sdt", latest), inline = true},
					{name = "Storage Size", value = util.fileSizeString(size), inline = true}
				}
			}})
		end)
		
	end
	
end

--[[do -- get files --
	local fs, appdata, watcher, path = require("fs"), require("directory"), require("fs-watcher"), require("path")
	
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
	
	if fs.existsSync(paths.appdata) then
		scanFiles("appdata", paths.appdata)
		watcher.watch(paths.appdata, true, function(...) processFile("appdata", ...) end)
	end
	
	fileLocations.temp = {}
	paths.temp = appdata.tempPath("")
	
	if fs.existsSync(paths.temp) then
		scanFiles("temp", paths.temp)
		watcher.watch(paths.temp, true, function(...) processFile("temp", ...) end)
	end
	
	fileLocations.garrysmod = {}
	paths.garrysmod = GARRYSMOD_DIR
	
	if fs.existsSync(paths.garrysmod) then
		scanFiles("garrysmod", paths.garrysmod)
		watcher.watch(paths.garrysmod, true, function(...) processFile("garrysmod", ...) end)
	end
	
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
end]]

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

do -- emoji hash command --
	
	local pretty, utf8 = require("pretty-print"), require("utf8")
	
	local Emoji = discordia.class.classes.Emoji
	
	benbebot:getCommand("1110366168952340540"):used({}, function(interaction, args)
		local emojiString = args.emoji:match("^%s*[^%s]+")
		
		local emoji
		local emojiName, emojiId = emojiString:match("^<:([^:]+):(%d+)>")
		if emojiId then
			local res = benbebot._api:request("GET", ("/guilds/%s/emojis/%s"):format(interaction.guild.id, emojiId))
			if res then
				interaction.guild.emojis:_insert(res)
				emoji = interaction.guild:getEmoji(emojiId)
			else
				emoji = {animated = false, managed = false, hash = emojiName .. ":" .. emojiId, mentionString = ("<:%s:%s>"):format(emojiName, emojiId), name = emojiName}
			end
		else
			emoji = {animated = false, managed = false, hash = emojiString, mentionString = emojiString}
		end
		
		interaction:reply({embed = {
			title = emoji.mentionString,
			fields = {
				{name = "Id", value = tostring(emoji.id), inline = true},
				{name = "Animated", value = tostring(emoji.animated), inline = true},
				{name = "Guild", value = tostring((emoji.guild or {}).name), inline = true},
				{name = "Hash", value = ("`%s`"):format(pretty.dump(emoji.hash):sub(2,-2)), inline = true},
				{name = "Mention", value = tostring(emoji.mentionString and ("`%s`"):format(emoji.mentionString)), inline = true},
				{name = "Managed", value = tostring(emoji.managed), inline = true},
				{name = "Name", value = tostring(emoji.name), inline = true},
				{name = "Url", value = tostring(emoji.url), inline = true}
			}
		}})
	end)
	
end

do -- misc stats --
	
	benbebot:on("guildCreate", function() local servers = benbebotStats.Servers benbebotStats.Servers = servers and (servers + 1) or benbebot.guilds:count() end)
	benbebot:on("guildDelete", function() local servers = benbebotStats.Servers benbebotStats.Servers = servers and (servers - 1) or benbebot.guilds:count() end)
	
	familyGuy:on("guildCreate", function() local servers = familyGuyStats.Servers familyGuyStats.Servers = servers and (servers + 1) or familyGuy.guilds:count() end)
	familyGuy:on("guildDelete", function() local servers = familyGuyStats.Servers familyGuyStats.Servers = servers and (servers - 1) or familyGuy.guilds:count() end)
	
end

do -- wakatime --
	
	local http, openssl, json = require("coro-http"), require("openssl"), require("json")
	
	local function find(tbl, name)
		for _,v in ipairs(tbl) do
			if v.name == name then
				return v
			end
		end
	end
	
	local function func()
		local res, body = http.request("GET", "https://wakatime.com/api/v1/users/current/stats", {{"Authorization", "Basic " .. openssl.base64(TOKENS.wakatime)}})
		if res.code < 200 or res.code >= 300 then return end
		
		body = json.parse(body).data
		
		local time
		
		if body.projects then
			local project = find(body.projects, "benbebots")
			time = project.text
		elseif body.languages then
			local language = find(body.languages, "Lua")
			time = language.text
		end
		
		benbebot:getChannel("1085752519487135795"):setName(time or "Programming")
	end
	
	clock:on("day", func)
	benbebot:on("ready", func)
	
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
		
		cannedFoodStats.Reactions = (cannedFoodStats.Reactions or 0) + 1
	end)
end

-- FAMILY GUY --

do -- clips --
	
	local json, http, uv, timer, urlParse, los = require("json"), require("coro-http"), require("uv"), require("timer"), require("url").parse, require("los")
	
	local CLIP_STORAGE = "1112531213094244362"
	local CLIP_FILE = appdata.path("clips.json")
	local clips = json.parse(fs.readFileSync(CLIP_FILE) or "[{\"version\":3}]") or {{version = 3}}
	
	local function saveClips()
		fs.writeFileSync(CLIP_FILE, json.stringify(clips or {{version = 3}}))
	end
	
	familyGuy:onSync("ready", function()
		if (not clips[1].version) or (clips[1].version < 3) then -- fix outdated tables
			for _,v in ipairs(clips) do
				if v[1] then
					local message = familyGuy:getChannel(CLIP_STORAGE):getMessage(v[1])
					
					familyGuy:info("fixing clip entry %d", _)
					
					if message then
						
						local attachmentUrl = urlParse(message.attachment.url)
						local id1, id2 = attachmentUrl.pathname:match("^/attachments/(%d+)/(%d+)")
						
						v[2], v[3] = id1, id2
						
					end
				end
			end
			
			table.insert(clips, 1, {version = 3})
			
			saveClips()
			
			familyGuy:info("fixed clip entries")
			
		end
	end)
	
	local clipCmd = familyGuy:getCommand("1125992663582257242")
	
	clipCmd:used({"add"}, function(interaction, args)
		local file = args.file
		if file.content_type ~= "video/mp4" then interaction:reply("file must be a mp4 video file") return end
		--[[local ratio = file.width / file.height
		if ratio < 1 then interaction:reply("file cannot be a verticle aspect ratio") return end]]
		interaction:replyDeferred()
		
		local res, content = http.request("GET", file.url)
		if res.code < 200 or res.code >= 300 or not content then interaction:reply("error fetching video data") return end
		
		local filename = ("clip_%s.mp4"):format(file.id)
		local message, err = familyGuy:getChannel("1112531213094244362"):send({
			file = {filename, content}
		})
		
		if not message then interaction:reply(err) return end
		
		local attachmentUrl = urlParse(message.attachment.url)
		local id1, id2 = attachmentUrl.pathname:match("^/attachments/(%d+)/(%d+)")
		
		table.insert(clips, {message.id, id1, id2, filename, interaction.user.id, args.season, args.episode})
		saveClips()
		
		interaction:reply({
			embed = {
				description = "succesfully added clip",
				fields = {
					{name = "ID", value = message.id, inline = true},
					{name = "Owner", value = interaction.user.mentionString, inline = true},
					{name = "Attribution", value = ("S%s E%s"):format(args.season or "?", args.episode or "?"), inline = true},
				}
			}
		})
		interaction.channel:send(message.attachment.url)
	end)
	
	local function removeEntry(id)
		local channel = familyGuy:getChannel("1112531213094244362")
		local message = channel:getMessage(id)
		
		if not message then return nil, "invalid clip id" end
		
		id = message.id
		message:delete()
		
		local toRemove = {}
		for i,v in ipairs(clips) do
			if v[1] == id then table.insert(toRemove, i) end
		end
		if #toRemove > 0 then
			for _,i in ipairs(toRemove) do table.remove(clips, i) end
			saveClips()
		end
		
		return true
	end
	
	clipCmd:used({"remove"}, function(interaction, args)
		interaction:replyDeferred()
		local success, err = removeEntry(args.id)
		
		interaction:reply(success and "removed clip" or err)
	end)
	
	local TIME_BETWEEN = 2 * 86400
	local BLOCKED_FILE = appdata.path("fg-blocked-users.json")
	
	local nextTimeStamp = math.huge
	local validUsers = {n = 0}
	local blockedUsers = json.parse(fs.readFileSync(BLOCKED_FILE) or "{}") or {}
	
	local function saveUsers()
		fs.writeFileSync(BLOCKED_FILE, json.stringify(blockedUsers or {}))
	end
	
	local function isBlocked(userId)
		local blocked = false
		for i,v in ipairs(blockedUsers) do
			if v == userId then blocked = i break end
		end
		return blocked
	end
	
	local function setBlocked(userId)
		table.insert(blockedUsers, userId)
		saveUsers()
		
		local index
		for i,v in ipairs(validUsers) do
			if v.id == userId then
				index = i
				break
			end
		end
		if index then
			table.remove(validUsers, index)
			validUsers.n = validUsers.n - 1
			familyGuyStats.Users = validUsers.n
		end
	end
	
	local function calcNextTimeStamp()
		local delay = math.floor(TIME_BETWEEN / validUsers.n)
		local sec = uv.gettimeofday()
		nextTimeStamp = math.floor(sec / delay + 1) * delay
		return nextTimeStamp
	end
	
	familyGuy:on("ready", function()
		for user in familyGuy.users:iter() do
			if not isBlocked(user.id) then
				validUsers.n = validUsers.n + 1
				table.insert(validUsers, user)
			end
		end
		
		calcNextTimeStamp()
		
		timer.sleep(5000)
		
		familyGuyStats.Users = validUsers.n
	end)
	
	local PREV_CLIP_FILE = appdata.path("previous-clips.json")
	local prevClips = json.parse(fs.readFileSync(PREV_CLIP_FILE) or "{}") or {}
	
	local function sendClip()
		local err, user, clip, content, success
		for i=1,5 do
			user = los.isProduction() and validUsers[math.random(validUsers.n)] or familyGuy:getChannel(TEST_CHANNEL)
			
			local prevClip = prevClips[user.id]
			
			for i=1,5 do
				clip = clips[math.random(2,#clips)]
				
				if clip[1] ~= prevClip then
					content = ("https://cdn.discordapp.com/attachments/%s/%s/%s"):format(clip[2], clip[3], clip[4])
					
					local res = http.request("HEAD", content)
					
					if res.code >= 200 and res.code < 300 then success = true break end
					
					familyGuy:output("warning", "family guy clip %s no longer exists (get attempt %s)", clip[1], i)
					
					--removeEntry(clip[1])
				else
					familyGuy:output("warning", "family guy clip %s is a duplicate of previous clip to %s (get attempt %s)", clip[1], user.id, i)
				end
			end
			
			if not success then return end
			
			success, err = user:send(content)
			
			if success then break end
			
			if err:match("^%s*HTTP%s*Error%s*50007") then -- user blocked error code
				familyGuy:output("warning", "failed to send clip to %s (blocked), adding to blocked users (attempt %s), %s", user.name, i, err)
				setBlocked(user.id)
			else
				familyGuy:output("warning", "failed to send clip to %s (attempt %s), %s", user.name, i, err)
			end
		end
		
		if not success then return end
		
		prevClips[user.id] = clip[1]
		fs.writeFileSync(PREV_CLIP_FILE, json.stringify(prevClips or {}))
		
		familyGuyStats.Clips = familyGuyStats.Clips + 1
		familyGuy:output("info", "sent family guy clip (ID %s) to %s", clip[1], user.name)
		return
	end
	
	clock:on("sec", function()
		local sec = uv.gettimeofday()
		
		if sec > nextTimeStamp then
			calcNextTimeStamp()
			
			sendClip()
		end
	end)
	
	clipCmd:used({"status"}, function(interaction, args)
		validUsers.n = #validUsers
		interaction:reply({embed = {
			description = ("next video will be sent <t:%d:R>"):format(nextTimeStamp),
			fields = {
				{name = "Users", value = validUsers.n, inline = true},
				{name = "Blocked Users", value = #blockedUsers, inline = true},
			}
		}})
	end)
	
	clipCmd:used({"force"}, function(interaction, args)
		sendClip()
		
		interaction:reply("sent clip")
	end)
	
	familyGuy:getCommand("1125992137733972029"):used({}, function(interaction)
		interaction:replyDeferred(true)
		local blocked = isBlocked(interaction.user.id)
		
		if blocked then
			table.remove(blockedUsers, blocked)
			saveUsers()
			
			table.insert(validUsers, interaction.user)
			validUsers.n = validUsers.n + 1
			familyGuyStats.Users = validUsers.n
			
			interaction:reply("you will now recieve family guy clips again", true)
		else
			setBlocked(interaction.user.id)
			
			interaction:reply("you will no longer recieve family guy clips", true)
		end
	end)
	
end

-- OTHER --

do -- reaction roles
	
	local messageData = {
		["1077041796779094096"] = { -- benbebots
			text = [[@everyone You know how this works
	<@&1075196966654451743> :face_holding_back_tears: - major updates involving the bots
	<@&1068664164786110554> :video_game: - game server events
	<@&1075245976543056013> :flag_pl: - polls involving this server
	<@&1072698350836662392> :sleeping: - get pinged when the bot's pfps are updated
	<@&1078400699802587136> :skull: - get pinged whenever i feel the urge to kill]],
			channel = "1075203623073632327",
			guild = "1068640496139915345",
			roles = {
				["\240\159\165\185"] = "1075196966654451743",
				["\240\159\142\174"] = "1068664164786110554",
				["\240\159\135\181\240\159\135\177"] = "1075245976543056013",
				["\240\159\152\180"] = "1072698350836662392",
				["\240\159\146\128"] = "1078400699802587136",
			}
		},
		["1110342430659715092"] = { -- smoke
			text = "Get your roles here! Getcha roles! Find yourself! Roles here! \n\240\159\148\181 : He/Him\n\240\159\148\180 : She/Her\n\240\159\159\163 : They/Them\n\240\159\159\161 : Other",
			channel = "1038142064719831110",
			guild = "1036666698104832021",
			roles = {
				["\240\159\148\181"] = "1038219440250167306",
				["\240\159\148\180"] = "1038219691749027911",
				["\240\159\159\163"] = "1038219768861315117",
				["\240\159\159\161"] = "1110365646908305418"
			}
		}
	}
	
	benbebot:on("ready", function()
		for message,data in pairs(messageData) do
			local channel = benbebot:getChannel(data.channel)
			if channel then
				message = channel:getMessage(message)
				if message then
					message:setContent(data.text)
				end
			end
		end
	end)
	
	local function add(_, messageId, hash, userId)
		local data = messageData[messageId]
		if not data then return end
		
		local role = data.roles[hash]
		if not role then return end
		
		benbebot:getGuild(data.guild):getMember(userId):addRole(role)
	end
	
	local function remove(channel, messageId, hash, userId)
		local data = messageData[messageId]
		if not data then return end
		
		local role = data.roles[hash]
		if not role then return end
		
		benbebot:getGuild(data.guild):getMember(userId):removeRole(role)
	end
	
	benbebot:on("reactionAddUncached", add)
	benbebot:on("reactionAdd", function(reaction, userId) add(reaction.message.channel, reaction.message.id, reaction.emojiHash, userId) end)
	
	benbebot:on("reactionRemoveUncached", remove)
	benbebot:on("reactionRemove", function(reaction, userId) remove(reaction.message.channel, reaction.message.id, reaction.emojiHash, userId) end)
	
end

do -- gnerb
	
	local GNERB_CHANNEL = "1126370471382880377"
	local POST_TIME = 7 -- 12:00 am pst
	
	local function func()
		local channel = fnafBot:getChannel(GNERB_CHANNEL)
		channel:send({file = "resource/gnerb.jpg"})
		
		fnafStats.gnerbs = (fnafStats.gnerbs or 0) + 1
		channel:setTopic(string.format("%d gnerbs", fnafStats.gnerbs))
		fnafBot:info("sent gnerb")
	end
	
	clock:on("hour", function(date)
		if date.hour ~= POST_TIME then return end
		func()
	end)
	
	fnafBot:getCommand("1126382357054771282"):used({"new"}, function(interaction)
		interaction:replyDeferred(true)
		
		func()
		
		interaction:reply("\240\159\145\141", true)
	end)
	
end

do -- remote manage server
	local http, fs, url = require("coro-http"), require("fs"), require("url")
	
	local TOKEN_FILE = require("los").isProduction() and ".tokens" or "alternate.tokens"
	
	privateServer:on("/token/upload", function(res, body)
		if (res.query or {}).pass ~= TOKENS.serverAuth then return {code = 401}, "Unauthorized" end
	
		local res = {fs.writeFileSync(TOKEN_FILE, body)}
		return nil, body
	end, {method = {"POST"}})
end

do -- netrc
	
	local timer, querystring, uv = require("timer"), require("querystring"), require("uv")
	
	local MY_URL = "http://10.0.0.222:" .. 26420 + portAdd
	local NETRC_FILE = appdata.secretPath(".netrc")
	io.open(NETRC_FILE, "ab"):close()
	
	privateServer:redirect("/netrc/get", "/netrc/index")
	privateServer:redirect("/netrc/set", "/netrc/index")
	privateServer:redirect("/netrc/lst", "/netrc/index")
	privateServer:redirect("/netrc/list", "/netrc/index")
	privateServer:redirect("/netrc/del", "/netrc/index")
	privateServer:redirect("/netrc/delete", "/netrc/index")
	
	function parse(l)
		return l:match("machine%s*([^%s]+)"), {login = l:match("login%s*([^%s]+)"),
			password = l:match("password%s*([^%s]+)"),
			account = l:match("account%s*([^%s]+)"),
			macdef = l:match("macdef%s*([^%s]+)")}
	end
	
	local function loadNetrc()
		local logins = {}
		
		for l in io.lines(NETRC_FILE) do
			local d = l:match("^%s*default")
			if d then
				_, default = parse(l)
			else
				local index, data = parse(l)
				for i,v in pairs(data) do
					data[i] = v:gsub("\\(..?)", function(chars)
						if chars:sub(1,1) == "\\" then return "\\" end
						return string.char(tonumber(chars, 16))
					end)
				end
				logins[index] = data
			end
		end
		
		return logins
	end
	
	local logins, loginTimer = nil, nil
	
	local function loadLogins()
		if not logins then
			logins = loadNetrc()
		end
		if loginTimer then timer.clearTimeout(loginTimer) end
		loginTimer = timer.setTimeout(20, function()
			logins, loginTimer = nil, nil
		end)
		
		return logins
	end
	
	local function saveNetrc(logins)
		local file = io.open(NETRC_FILE, "wb")

		for machine,login in pairs(logins) do
			local str = {"machine", machine}
			for i,v in pairs(login) do
				table.insert(str, i)
				table.insert(str, v)
			end
			file:write(table.concat(str, " "), "\n")
		end

		if default then
			local str = {"default"}
			for i,v in pairs(default) do
				table.insert(str, i)
				table.insert(str, v)
			end
			file:write(table.concat(str, " "))
		end
		
		file:close()
	end
	
	local charset = {n = 0} -- init charset
	for char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"):gmatch(".") do table.insert(charset, char) charset.n = charset.n + 1 end
	
	privateServer:on("/netrc/index", function(res)
		loadLogins()
		
		if not res.query then return end
		if res.query.machine then
			local data = logins[res.query.machine]
			if not data then return {code = 404} end
			
			local html = {"<body><h1>", res.query.machine, "</h1>"}
			for name,value in pairs(data) do
				table.insert(html, "<h2>") table.insert(html, name) table.insert(html, "</h2>")
				table.insert(html, "<p>") table.insert(html, value) table.insert(html, "</p>")
			end
			table.insert(html, "</body>")
			
			return {code = 200}, table.concat(html)
		end
		
		local html = {"<body>"}
		for machine,login in pairs(logins) do
			table.insert(html, "<a href=\"")
			table.insert(html, "/netrc/index?pass=" .. tostring(res.query.pass) .. "&machine=" .. machine)
			table.insert(html, "\">")
			table.insert(html, machine)
			table.insert(html, "</a><br>")
		end
		table.insert(html, "<a href=\"/netrc/new\">+new</a>")
		table.insert(html, "</body>")
		
		return {{"Cache-Control", "no-store"}, code = 200}, table.concat(html)
	end, {method = {"GET"}})
	
	privateServer:on("/netrc/new", function(res)
		if res.method == "GET" then
			return {code = 200}, [[<body>
	<form action="/netrc/new" method="post">
		<label for="machine">machine</label><br>
		<input type="text" id="machine" name="machine" value="machine"><br>
		<label for="login">login</label><br>
		<input type="text" id="login" name="login" value="login"><br>
		<label for="password">password</label><br>
		<input type="text" id="password" name="password" value="password"><br>
		<label for="account">account</label><br>
		<input type="text" id="account" name="account" value="account"><br><br>
		<input type="submit" value="create">
	</form>
</body>]]
		end
		loadLogins()
		
		local data = querystring.parse(res.body)
		if not data then return {code = 400} end
		if logins[data.machine] then return {code = 403} end
		local login = {machine = data.machine, login = data.login, password = data.password, account = data.account}
		
		if login.password then
			login.password = login.password:gsub("%%auto(%b[])", function(args)
				local pass = {}
				for i=1,32 do
					math.randomseed(string.unpack("I4", uv.random(4)))
					pass[i] = charset[math.random(charset.n)]
				end
				return table.concat(pass)
			end)
		end
		
		for index,value in pairs(login) do
			login[index] = value:match("^.+$")
			if login[index] then
				login[index] = value:gsub("[%s\\]", function(char)
					if char == "\\" then return "\\\\" end
					return ("\\%02x"):format(string.byte(char))
				end)
			end
		end
		
		local machine = login.machine login.machine = nil
		logins[data.machine] = login
		
		saveNetrc(logins)
	end, {method = {"GET", "POST"}})
	
end

do -- events
	
	local json, http, querystring, url, openssl, uv = require("json"), require("coro-http"), require("querystring"), require("url"), require("openssl"), require("uv")
	local null = json.null
	
	local EVENT_FILE = appdata.path("events.json")
	local events = json.parse(fs.readFileSync(EVENT_FILE) or "{}") or {}
	-- {owner, masterMessage, message, isActive, channel, misc}
	
	local function saveEvents()
		fs.writeFileSync(EVENT_FILE, json.stringify(events or {}))
	end
	
	local function formatMessage(pattern, message, url)
		return pattern:gsub("%$%b{}", function(str)
			if str == "${message}" then return message or ""
			elseif str == "${url}" then return url or ""
			else return ""
			end
		end)
	end
	
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
	
	local user, admin = benbebot:getCommand("1107064787294236803"), benbebot:getCommand("1110642726703218768")
	
	-- pubsubhubbub
	
	local bString = "B"
	local function generateSecret()
		local bin = uv.random(32)
		local buffer = {}
		for i=1,32 do
			table.insert(buffer, openssl.bn.tohex(bString:unpack(bin:sub(i,i))))
		end
		return table.concat(buffer)
	end
	
	local verificationState = nil
	
	admin:autocomplete({"pubsubhubbub"}, acId)
	admin:used({"pubsubhubbub"}, function(interaction, args)
		if not benbebot:getGuild(BOT_GUILD):getMember(interaction.user.id):hasRole("1068640885581025342") then interaction:reply("you must be a bot admin to use this sub command") return end
		if true then interaction:reply("broke ass command do not use") return end
		if verificationState then interaction:reply("already in progress") return end
		if not events[args.id] then interaction:reply("event id does not exist") return end
		interaction:replyDeferred()
		
		local topicData = url.parse(args.topic)
		
		local payload = {
			callback = "http://68.146.47.120:26430/notifs/pubsubhubbub?" .. querystring.stringify({service = service, event = args.id}),
			mode = (args.subscribe == nil or args.subscribe) and "subscribe" or "unsubscribe",
			topic = args.topic,
			secret = generateSecret()
		}
		
		verificationState = {
			id = args.id,
			topic = payload.topic,
			secret = payload.secret,
			success = nil,
			thread = nil
		}
		
		local res, err = http.request(args.hub, 
			{{"Content-Type", "application/x-www-form-urlencoded"}},
			querystring.stringify(verificationState)
		)
		
		if res.code ~= 202 then interaction:reply("there was an error submitting a subscription request: " .. err) return end
		
		if verificationState.success == nil then
			verificationState.thread = coroutine.running()
			verificationState.success = coroutine.yield()
			verificationState.thread = nil
		end
		
		if not verificationState.success then interaction:reply("could not verify") return end
		
		events[args.id][6] = {}
		events[args.id][6].secret = verificationState.secret
		saveEvents()
		
		verificationState = nil
		
		interaction:reply("success")
		
	end)
	
	local function resume(success)
		if verificationState.thread then
			coroutine.resume(verificationState.thread, success)
		end
		verificationState.success = success
	end
	
	publicServer:on("/notifs/pubsubhubbub", function(req)
		
		if req.method == "GET" then -- verification or cancelation request
			if not req.search then return {code == 404} end
			local search = req.search:sub(2,-1):gsub("%?", "&") -- fix querys
			local query = querystring.parse(search)
			
			p("X-Hub-Signature")
			
			if query.mode == "denied" then
				if verificationState.id == query.event then resume(false, query.reason) return end
				
				events[args.id][6] = {}
				saveEvents()
				
				benbebot:output("warn", "Event %s pubsubhubbub subscription denied: %s", query.event, query.reason)
				
				return
			end
			
			
			
			resume(true)
			return
		end
		
		if not req.query then return {code == 404} end
		local event = events[req.query.event]
		if not event then return {code == 404} end
		
		local hubSig = req:getHeader("X-Hub-Signature")
		if not hubSig then return false, "missing hmac header" end
		
		local alg alg, hubSig = hmacSig:match("^(.-)=(.+)$")
		local subSig = openssl.hmac.hmac(alg and "sha1", event[6].secret, req.body, false)
		if hubSig ~= subSig then return end
		
		--TODO
		
		return {code = 500}
	end, {method = {"GET", "POST"}})
	
	-- zapier
	
	admin:autocomplete({"zapier"}, acId)
	admin:used({"zapier"}, function(interaction, args)
		if not benbebot:getGuild(BOT_GUILD):getMember(interaction.user.id):hasRole("1068640885581025342") then interaction:reply("you must be a bot admin to use this sub command") return end
		
		events[args.id][6] = {}
		events[args.id][6].youtubeId = args.channel
		saveEvents()
		
		interaction:reply("success")
	end)
	
	benbebot:on("messageCreate", function(message)
		if message.channel.id == "1110637295826116678" then
			local site, channelId, url = message.content:match("^.-[\n\r]+(.-)[\n\r]+(.-)[\n\r]+(.-)$")
			if site ~= "youtube" then return end
			
			local event
			for id,data in pairs(events) do
				if data[6] and data[6].youtubeId == channelId then
					event = data
					break
				end
			end
			
			if not event then benbebot:output("warning", "failed to find event for zap: %s", message.id) return end
			
			benbebot:getChannel(event[5]):send(formatMessage(event[2], event[3], url))
		end
	end)
	
	-- managing
	
	local changedPattern = "changed %s from `%s` to `%s`"
	local messagePattern = "%s\n\nthis will look like:\n%s"
	
	user:autocomplete({"master"}, acId)
	user:used({"master"}, function(interaction, args)
		local beforeValue = events[args.id][2]
		events[args.id][2] = args.message or json.null
		saveEvents()
		
		interaction:reply(messagePattern:format(changedPattern:format("master message", tostring(beforeValue), tostring(events[args.id][2])), formatMessage(events[args.id][2], events[args.id][3], "https://example.com/")))
	end)
	
	user:autocomplete({"message"}, acId)
	user:used({"message"}, function(interaction, args)
		local beforeValue = events[args.id][3]
		events[args.id][3] = args.message or json.null
		saveEvents()
		
		interaction:reply(messagePattern:format(changedPattern:format("message", tostring(beforeValue), tostring(events[args.id][3])), formatMessage(events[args.id][2], events[args.id][3], "https://example.com/")))
	end)
	
	user:autocomplete({"active"}, acId)
	user:used({"active"}, function(interaction, args)
		local beforeValue = events[args.id][4]
		events[args.id][4] = args.active
		saveEvents()
		
		interaction:reply(changedPattern:format("active", tostring(beforeValue), tostring(events[args.id][4])))
	end)
	
	user:autocomplete({"channel"}, acId)
	user:used({"channel"}, function(interaction, args)
		if not (args.channel or args.channelid) then interaction:reply("please specify a channel") return end
		local beforeValue = events[args.id][5]
		events[args.id][5] = args.channel or args.channelid or json.null
		saveEvents()
		
		interaction:reply(changedPattern:format("channel", tostring(beforeValue), tostring(events[args.id][5])))
	end)
	
	admin:used({"new"}, function(interaction, args)
		if not benbebot:getGuild(BOT_GUILD):getMember(interaction.user.id):hasRole("1068640885581025342") then interaction:reply("you must be a bot admin to use this sub command") return end
		if events[args.id] then interaction:reply("event id already exists") return end
		events[args.id] = {args.owner or json.null, args.master or json.null, args.message or json.null, args.active or json.null, args.channel or json.null, json.null}
		saveEvents()
		
		interaction:reply("succesfully created event: " .. args.id)
	end)
	
end

do -- get cannedFood token
	local http, json, timer, los = require("coro-http"), require("json"), require("timer"), require("los")
	
	local res, body
	for _=1,los.isProduction() and 3 or 1 do
		res, body = http.request("POST", "https://discord.com/api/v9/auth/login", {{"content-type", "application/json"}}, json.stringify({
			captcha_key = json.null,
			login = TOKENS.cannedFoodEmail,
			password = TOKENS.cannedFoodPassword,
			undelete = false
		}))
		
		if res.code >= 200 and res.code < 300 then break end
		
		local resp = json.parse(body)
		
		cannedFood:warning("failed to scrape token, retrying after %ss", resp.retry_after * 2)
		
		timer.sleep((resp.retry_after or 0) * 2000)
	end
	
	if res.code ~= 200 then cannedFood:error("could not scrape token: %s", body) end
	
	TOKENS.cannedFood = json.parse(body).token
end

do -- server pings
	
	local function ping(req)
		return
	end
	
	privateServer:on("/ping", ping, {method = {"GET"}})
	publicServer:on("/ping", ping, {method = {"GET"}})
	
end

local readys, thread = 0, coroutine.running()
local function func() readys = readys + 1 coroutine.resume(thread) end

benbebot:onceSync("ready", func) benbebot:onceSync("error", func) benbebot:run("Bot " .. tostring(TOKENS.benbebot))
familyGuy:onceSync("ready", func) familyGuy:onceSync("error", func) familyGuy:run("Bot " .. tostring(TOKENS.familyGuy))
uncannyCat:onceSync("ready", func) uncannyCat:onceSync("error", func) uncannyCat:run("Bot " .. tostring(TOKENS.uncanny))
fnafBot:onceSync("ready", func) fnafBot:onceSync("error", func) fnafBot:run("Bot " .. tostring(TOKENS.fnaf))
cannedFood:onceSync("ready", func) cannedFood:onceSync("error", func) cannedFood:run(tostring(TOKENS.cannedFood))

repeat coroutine.yield() until readys >= 5

genericLogger:info("All bots ready")

local success1, err1 = privateServer:start()
local success2, err2 = publicServer:start()

if not (success1 and success2) then
	genericLogger:error("Failed to start TCP server(s)")
	print(err1)
	print(err2)
else
	genericLogger:info("TCP servers started")
end

reseedRandom()

clock:start(true)

genericLogger:info("Started clock")