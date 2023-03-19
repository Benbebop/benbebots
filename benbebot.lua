local uv, fs, appdata = require("uv"), require("fs"), require("data")

local discordia = require("discordia") require("token")--require("discordia-interactions") require("discordia-commands")
local enums = discordia.enums

local client = discordia.Client()

do -- RSS
	
	local timer, http, xml = require("timer"), require("coro-http"), require("slaxml")
	
	local rssFile, fileFormat = appdata.path("rss-timestamps.db"), "zL"
	local rssToEmbed = {title = "title", description = "description", link = "url", pubDate = "timestamp", enclosure = "enclosure"}
	local endpoints = {
		{"Steamworks", "1068657073321169067", "https://store.steampowered.com/feeds/news/group/4145017"}, 
		{"Garry's Mod", "1068657073321169067", "https://store.steampowered.com/feeds/news/app/4000"},
		{"Lua", "1068657073321169067", "https://www.lua.org/news.rss"}
	}

	client:on("ready", function()
		
		local latests = {}
		
		local data = fs.readFileSync(rssFile)
		if data then
			for part in data:gmatch("[^%z]+.....") do
				local url, timestamp = fileFormat:unpack(part)
				latests[url] = discordia.Date().fromSeconds(timestamp)
			end
		end
		
		local function feedFunc(endpoint)
			latests[endpoint[3]] = latests[endpoint[3]] or discordia.Date(0,0)
			
			local success, result, body = pcall(http.request, "GET", endpoint[3])
			
			if not success then
				client:warning("RSS Feed Failed: " .. body)
				return
			end
			
			local embed, index
			
			xml:parser({
				startElement = function(name)
					if name == "item" then
						if embed then client:getChannel(endpoint[2]):send({embed = embed}) end
						embed = {author = {name = endpoint[1]}}
					elseif embed then
						index = rssToEmbed[name]
					end
				end,
				attribute = function(name,value)
					if index == "enclosure" and name == "url" then
						embed.image = {url = value}
					end
				end,
				text = function(text)
					if index then
						if index == "timestamp" then
							local date = discordia.Date().fromHeader(text:gsub("[%+%-]%d+", "GMT"))
							if date:toSeconds() < (latests[endpoint[3]]:toSeconds() + 10) then embed, index = nil, nil return end
							latests[endpoint[3]] = date
							embed.timestamp = date:toISO()
						elseif index == "link" then
							embed.url = text
						elseif index == "description" then
							embed.description = text:gsub("%b<>", ""):gsub("%b[]", ""):sub(1,200) .. "..."
						elseif index ~= "enclosure" then
							embed[index] = text
						end
					end
				end
			}):parse(body,{stripWhitespace=true})
			
			local file = fs.openSync(rssFile, "w")
			local cursor = 0
			for i,v in pairs(latests) do
				local data = fileFormat:pack(i, v:toSeconds())
				fs.writeSync(file, cursor, data)
				cursor = cursor + #data
			end
			fs.closeSync(file)
			
		end
		
		timer.setInterval(1000 * 60 * 60, function()
			for _,v in ipairs(endpoints) do
				coroutine.wrap(feedFunc)(v)
			end
		end)
		
		for _,v in ipairs(endpoints) do
			coroutine.wrap(feedFunc)(v)
		end
		
	end)

end

client:run("Bot " .. TOKENS.benbebot)