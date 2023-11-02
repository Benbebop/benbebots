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
benbebot:enableIntents(discordia.enums.gatewayIntent.guildMembers, discordia.enums.gatewayIntent.guildPresences) familyGuy:enableIntents(discordia.enums.gatewayIntent.guildMembers) uncannyCat:enableIntents(discordia.enums.gatewayIntent.guildMembers, discordia.enums.gatewayIntent.messageContent)
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

do
	local spawn, http = require("coro-spawn"), require("coro-http")

	local BREADBAG = "822165179692220476"

	local WIKI_PATH = "/var/www/breadbag-wiki/"
	local HASH_FILE = appdata.path("breadbag_icon.hash")
	local LOGO_FILE_TEMP = appdata.tempPath("breadbag_icon.tmp")
	local LOGO_FILES = {
		{appdata.tempPath("breadbag_icon.png"), WIKI_PATH .. "resources/assets/breadbag_icon.png"},
		{appdata.tempPath("breadbag_icon.png"), WIKI_PATH .. "resources/assets/breadbag_icon_130.png"},
		{appdata.tempPath("breadbag_icon.ico"), WIKI_PATH .. "favicon.ico"}
	}
	local function processLogo(part, args, dest)
		part, dest = appdata.tempPath(part), WIKI_PATH .. dest
		args[#args + 1] = part

		local proc = spawn("ffmpeg", {args = args})
		proc:waitExit()

		fs.unlinkSync(LOGO_FILE_TEMP)
		fs.unlinkSync(dest)
		fs.renameSync(part, dest)
	end

	local function dlBreadBagIcon(guild)
		if not guild.icon then return end

		local logoHash = fs.readFileSync(HASH_FILE) or ""
		if logoHash == guild.icon then return end
		fs.writeFileSync(HASH_FILE, guild.icon)
		
		local _, body = http.request("GET", guild.iconURL)
		fs.writeFileSync(LOGO_FILE_TEMP, body)

		processLogo("breadbag_icon.png", {"-y", "-i", LOGO_FILE_TEMP, "-vf", "scale=100x100"}, "resources/assets/breadbag_icon.png")
		processLogo("breadbag_icon.png", {"-y", "-i", LOGO_FILE_TEMP, "-vf", "scale=135x155"}, "resources/assets/breadbag_icon_1x.png")
		--ffmpeg -i breadbag_icon.png -filter_complex split[r32][r16],[r32]scale=32x32,[r16]scale=16x16 out.ico
		processLogo("breadbag_icon.ico", {"-y", "-i", LOGO_FILE_TEMP, "-filter_complex", "split[r32][r16],[r32]scale32x32,[r16]scale16x16"}, "favicon.ico")
	end
	
	benbebot:on("ready", function() dlBreadBagIcon(benbebot:getGuild(BREADBAG)) end)

	benbebot:on("guildUpdate", function(guild)
		if guild.id ~= BREADBAG then return end
		dlBreadBagIcon(guild)
	end)

end

do -- commands --
	
	benbebot:getCommand("1128437755614081052"):used({}, function(interaction) -- ping larry
		interaction:reply("<@463065400960221204>")
	end)
	
	benbebot:getCommand("1130670943883251732"):used({}, function(interaction) -- ping everything
		local strings = {"@everyone ", "@here ", n = 0}
		local function addToBuffer(o) strings.n = strings.n + 1 table.insert(strings, o.mentionString) end
		
		local guild = interaction.guild
		guild.members:forEach(addToBuffer)
		guild.roles:forEach(addToBuffer)
		guild.textChannels:forEach(addToBuffer)
		
		local buffer, len, interact = "", 0, true
		while strings.n > 0 do
			local index = math.random(strings.n)
			local str = strings[index] table.remove(strings, index) strings.n = strings.n - 1
			local strLen = #str
			
			if (len + strLen) > 2000 then
				if interact then
					interaction:reply(buffer)
					interact = false
				else
					interaction.channel:send(buffer)
				end
				buffer, len = str, strLen
			else
				buffer = buffer .. str
				len = len + strLen
			end
		end
	end)
	
end

do -- nicklockdown
	
	local timer = require("timer")

	local lockdownIndex = false

	local arrestQueue = {}
	benbebot:on("memberUpdate", function(member)
		if not lockdownIndex then return end
		if member.guild.id ~= "822165179692220476" then return end

		local lockdownName = lockdownIndex[member.id]
		if not lockdownName then
			lockdownIndex[member.id] = member.nickname
			return
		end

		-- arrest pending --
		local arrest = arrestQueue[member.id]
		if arrest then
			if member.nickname == lockdownName then
				timer.clearTimeout(arrest)
				arrestQueue[member.id] = nil
				member.user:send(string.format("you have succesfully restored your nickname in %s, ban cancelled.", member.guild))
				return
			end
			member.user:send(string.format("your nickname in %s still does not match logged lockdown name: \"%s\".", member.guild.name, lockdownName))
			return
		end

		-- create arrest --
		if member.nickname == lockdownName then return end
		member.user:send(string.format("it appears you have changed your nickname from %s in %s while it is on nickname lockdown. if you do not change your nickname back you will be banned in 10 minutes. make good use of your remaining time!", lockdownName, member.guild.name))
		arrestQueue[member.id] = timer.setTimeout(600000, function()
			arrestQueue[member.id] = nil
			member.user:send("looks like you ran out of time stupid")
			member:kick("violated nickname lockdown")
		end)
	end)

	local processing = false
	benbebot:getCommand("1160813279518670919"):used({}, function(interaction)
		if processing then interaction:replyDeferred("WAIT FOR A FUCKING SECOND IM BUSY") return end
		processing = true
		if not lockdownIndex then
			interaction:reply("fetching current nicknames... please wait 3 seconds...")
			interaction.guild:requestMembers()
			timer.sleep(2500)
			lockdownIndex = {}
			interaction.guild.members:forEach(function(member)
				lockdownIndex[member.id] = member.nickname
			end)
			interaction:getReply():setContent("lockdown now in order")
			processing = false
			return
		end
		
		interaction:reply("lifting lockdown... please wait...")

		for i,v in pairs(arrestQueue) do
			benbebot:getUser(i):send("lockdown has been lifted, your ban has been cancelled.")
			timer.clearTimeout(v)
		end
		arrestQueue = {}
		processing = false

		lockdownIndex = false
		interaction:getReply():setContent("lockdown has been lifted")
	end)

end

do -- league 
	
	benbebot:on("presenceUpdate", function(member)
		if member.guild.id ~= "822165179692220476" then return end
	end)
	
end

do -- play fish21 videos
	
	local youtube, util, json = require("web/youtube").new(TOKENS.youtube), require("util"), require("json")
	local ffmpegPipe = require("ffmpeg-pipe")
	
	local videos = {n = 0}
	
	local FISH_VIDEO_PLAYLIST = "UULFi7mOHUUzZ1Jron1ov7MQkw"
	
	benbebot:on("ready", function()
		local page, total
		repeat
			local res, body = youtube:request("GET", "playlistItems", {part = "contentDetails", playlistId = FISH_VIDEO_PLAYLIST, maxResults = 50, pageToken = page})
			if res.code ~= 200 then benbebot:output("error", "failed to get playlist page (%s)", page) return end
			body = json.parse(body)
			if not body then benbebot:output("error", "youtube provided invalid json") return end
			total = total or util.indexTable(body, {"pageInfo", "totalResults"})
			for _,v in ipairs(body.items or {}) do
				local id = util.indexTable(v, {"contentDetails", "videoId"})
				if id then util.ninsert(videos, id) end
			end
			page = body.nextPageToken
		until not page
		
		if videos.n ~= total then benbebot:output("warning", "cached video count (%d) does not match provided count (%d)", videos.n, total) end
	end)
	
	local session
	
	local cmd = benbebot:getCommand("1135788072395608064")
	
	cmd:used({"start"}, function(interaction, args)
		if session then interaction:reply("already doing something, stupid", true) return end
		session = {}
		
		local channel = util.indexTable(interaction, {"member", "voiceChannel"})
		if not channel then interaction:reply("you must be in a voice channel to use this command", true) session = nil return end
		
		interaction:replyDeferred()
		local err session.connection, err = channel:join()
		if not session.connection then interaction:reply(string.format("could not join voice channel (%s)", err)) session = nil return end
		
		local video
		
		if args.vido then
			video = youtube.parseUrl(args.vido)
		else
			video = videos[math.random(videos.n)]
		end
		
		if not video then interaction:reply("i really dont care enough to write this error") return end
		interaction:reply("starting :)") 
		
		session.running = true
		repeat
			local res, body = youtube:request("GET", "playlistItems", {part = "snippet", playlistId = FISH_VIDEO_PLAYLIST, maxResults = 1, videoId = video})
			if res.code ~= 200 then interaction.channel:send(string.format("could not find video on fish21 channel (%s)", video)) break end
			body = json.parse(body)
			if not body then break end
			if util.indexTable(body, {"pageInfo", "totalResults"}) < 1 then break end
			interaction.channel:send(string.format("playing %s", tostring(util.indexTable(body, {"items", 1, "snippet", "title"}))))
			
			local stdin = uv.new_pipe(true)
			session.downloader = uv.spawn("yt-dlp", {
				args = {"-o", "-", video},
				stdio = {0, stdin, 2}
			})
			session.stream = ffmpegPipe(stdin, 48000, 2)
			
			connection:_play(session.stream)
			
			session.downloader:kill()
			session.stream:kill()
			
			if not doRepeat then
				video = videos[math.random(videos.n)]
			end
		until not session.running
		
		session.connection:close()
		session = nil
	end)
	
	local function stop(mode, interaction)
		if (not session) or (not session.running) then interaction:reply("not playing anything :/", true) return end
		if util.indexTable(interaction, {"member", "voiceChannel"}) ~= session.connection.channel then interaction:reply("you must be in the same channel to stop the bot", true) return end
		
		if mode then session.running = false end
		session.downloader:kill()
		session.stream:kill()
	end
	
	cmd:used({"stop"}, function(...) stop(true, ...) end)
	cmd:used({"skip"}, function(...) stop(false, ...) end)
	
end

do -- XD
	
	benbebot:on("voiceUpdate", function(member)
		if member.guild.id ~= "822165179692220476" then return end
		if member.id ~= "459880024187600937" then return end
		if not member.muted then return end
		
		member:unmute()
	end)
	
	local fakeMember = {unmute = function() end}
	local fakeGuild = {getMember = function() return fakeMember end}
	
	benbebot:on("ready", function()
		((benbebot:getGuild("822165179692220476") or fakeGuild):getMember("459880024187600937") or fakeMember):unmute()
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
	local emoji, timer = "\240\159\165\171", require("timer")
	
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
			"1020127285229146112", -- ghetto smosh
			"983936473218818078" -- idfk
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
		local delay = math.random(1,4000)
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

-- UNCANNY CAT --

do -- clips --
	
	local json, http, uv, timer, urlParse, los = require("json"), require("coro-http"), require("uv"), require("timer"), require("url").parse, require("los")
	
	local BLOCKSIZE, ALLOWED_TYPES, TIME_BETWEEN = 100, {"video/mp4", "video/gif", "gifv", "image", "video"}, 345600
	local BLOCKED_FILE = appdata.path("uc-blocked-users.json")
	
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
			uncannyStats.Users = validUsers.n
		end
	end
	
	local function calcNextTimeStamp()
		local delay = math.floor(TIME_BETWEEN / validUsers.n)
		local sec = uv.gettimeofday()
		nextTimeStamp = math.floor(sec / delay + 1) * delay
		return nextTimeStamp
	end
	
	uncannyCat:on("ready", function()
		for user in uncannyCat.users:iter() do
			if not isBlocked(user.id) then
				validUsers.n = validUsers.n + 1
				table.insert(validUsers, user)
			end
		end
		
		calcNextTimeStamp()
	end)
	
	local clips = {}
	
	local function refreshClips()
		clips = {}
		local channel = uncannyCat:getChannel("1124571481284825179")
		if not channel then uncannyCat:output("error", "unable to get cat source channel") return end
		
		local count = 0
		local messages = channel:getMessagesAfter(channel:getFirstMessage(), BLOCKSIZE)
		if not messages then return end
		while #messages > 0 do
			local sorted = messages:toArray("createdAt")
			for _,m in ipairs(sorted) do
				local embed = m.attachment or m.embed
				if embed then
					local valid = false
					for i,v in ipairs(ALLOWED_TYPES) do
						if (embed.type or embed.contentType) == v then
							valid = true
							break
						end
					end
					if valid then
						table.insert(clips, embed.url)
					end
				end
			end
			messages = channel:getMessagesAfter(sorted[#sorted], BLOCKSIZE)
		end
	end
	
	uncannyCat:on("ready", refreshClips)
	clock:on("day", refreshClips)
	
	local function sendClip()
		local err, user, clip, content, success
		for i=1,5 do
			user = los.isProduction() and validUsers[math.random(validUsers.n)] or uncannyCat:getChannel(TEST_CHANNEL)
			
			for i=1,5 do
				content = clips[math.random(1,#clips)]
				
				local res = http.request("HEAD", content)
				
				if res.code >= 200 and res.code < 300 then success = true break end
				
				uncannyCat:output("warning", "uncanny cat %s no longer exists (get attempt %s)", "?", i)
				
				--removeEntry(clip[1])
			end
			
			if not success then return end
			
			success, err = user:send(content)
			
			if success then break end
			
			if err:match("^%s*HTTP%s*Error%s*50007") then -- user blocked error code
				uncannyCat:output("warning", "failed to send cat to %s (blocked), adding to blocked users (attempt %s), %s", user.name, i, err)
				setBlocked(user.id)
			else
				uncannyCat:output("warning", "failed to send cat to %s (attempt %s), %s", user.name, i, err)
			end
		end
		
		if not success then return end
		
		uncannyStats.Clips = uncannyStats.Clips + 1
		uncannyCat:output("info", "sent uncanny cat %s to %s", "?", user.name)
		return
	end
	
	clock:on("sec", function()
		local sec = uv.gettimeofday()
		
		if sec > nextTimeStamp then
			calcNextTimeStamp()
			
			sendClip()
		end
	end)
	
	local clipCmd = uncannyCat:getCommand("1131728984305057932")
	
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
		interaction:replyDeferred()
		
		sendClip()
		
		interaction:reply("sent clip")
	end)
	
	uncannyCat:getCommand("1131710344042127413"):used({}, function(interaction)
		interaction:replyDeferred(true)
		local blocked = isBlocked(interaction.user.id)
		
		if blocked then
			table.remove(blockedUsers, blocked)
			saveUsers()
			
			table.insert(validUsers, interaction.user)
			validUsers.n = validUsers.n + 1
			uncannyStats.Users = validUsers.n
			
			interaction:reply("you are now canny", true)
		else
			setBlocked(interaction.user.id)
			
			interaction:reply("you are now uncanny", true)
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

do -- say hi to fish21 
	
	local ACTIVE_STATUS = {"online", "dnd"}
	
	local wasOnline = true
	benbebot:on("ready", function() benbebot:getUser("823215010461384735") end)
	
	local function isOffline(status)
		for _,v in ipairs(ACTIVE_STATUS) do
			if v == status then return false end
		end
		return true
	end
	
	benbebot:on("presenceUpdate", function(member)
		if wasOnline then return end
		if member.id ~= "823215010461384735" then return end
		if isOffline(status) then return end
		
		wasOnline = true
		member.author:send("https://cdn.discordapp.com/attachments/1068657073321169067/1132195619189035018/goodmorning.mp4")
	end)
	
	clock:on("hour", function(date)
		if date.hour == 8 then return end
		
		wasOnline = false
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
