local http, json, appdata = require("coro-http"), require("json"), require("../appdata")

appdata.init({{"motd.dat", "{}"}})

local initFile = appdata.get("motd.dat")
local motd = json.parse(initFile:read("*a"))
initFile:close()

local m = {}

local function get()
	local mashup, artist, song, count = io.lines("scBackup.txt"), "", "", 0
	
	repeat
		artist, song = mashup():match("(.+)%.(.+)")
		
		if not artist then return end
		
		if not motd[artist] then motd[artist] = {} end
		
		local exists = false
		for i,v in ipairs(motd[artist]) do
			if v == song then
				
				exists = true
				
			end
		end
		count = count + 1
	until not exists
	
	return artist, song, count
end

function m.getMashup()
	local artist, song = get()
	
	if not artist then return end
	
	table.insert(motd[artist], song)
	
	local motdfile = appdata.get("motd.dat", "wb")
	motdfile:write(json.stringify(motd))
	motdfile:close()
	
	return artist .. "/" .. song
end

function m.nextMashup()
	local artist, song = get()
	
	if not artist then return end
	
	return artist .. "/" .. song
end

function m.count()
	local file = io.open("scBackup.txt", "rb")
	local _, count = file:read("*a"):gsub("\n", "")
	file:close()
	local _, _, index = get()
	return count, index
end

local postTimes = {["0"] = "12", ["1"] = "16", ["2"] = "16", ["3"] = "16", ["4"] = "16", ["5"] = "14", ["6"] = "12"}

function m.getPostTime()
	return postTimes[os.date("%w")]
end

return m