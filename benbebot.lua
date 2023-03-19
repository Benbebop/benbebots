local uv = require("uv")

local discordia = require("discordia") require("token")--require("discordia-interactions") require("discordia-commands")
local enums = discordia.enums

local client = discordia.Client()

local timer, http, xml = require("timer"), require("coro-http"), require("slaxml")

local rssToEmbed = {title = "title", description = "description", link = "url", pubDate = "timestamp", enclosure = "enclosure"}

client:on("ready", function() -- RSS
	
	local latests = {}
	
	local c = client:getChannel("1068657073321169067")
	
	local function feedFunc(endpoint)
		latests[endpoint[2]] = latests[endpoint[2]] or discordia.Date(0,0)
		
		local success, result, body = pcall(http.request, "GET", endpoint[2])
		
		if not success then
			client:warning("RSS Feed Failed: " .. body)
			return
		end
		
		local embed, index
		
		xml:parser({
			startElement = function(name)
				if name == "item" then
					if embed then c:send({embed = embed}) end
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
						local date = discordia.Date().fromHeader(text:gsub("%+%d+", "GMT"))
						if date < latests[endpoint[2]] then embed, index = nil, nil return end
						latests[endpoint[2]] = date
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
		
	end
	
	local endpoints = {{"Steamworks", "https://store.steampowered.com/feeds/news/group/4145017"}, {"Garry's Mod", "https://store.steampowered.com/feeds/news/app/4000/"}}
	
	timer.setInterval(1000 * 60 * 60, function()
		for _,v in ipairs(endpoints) do
			coroutine.wrap(feedFunc)(v)
		end
	end)
	
	for _,v in ipairs(endpoints) do
		coroutine.wrap(feedFunc)(v)
	end
	
end)

client:run("Bot " .. TOKENS.benbebot)