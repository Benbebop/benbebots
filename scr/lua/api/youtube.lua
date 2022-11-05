local http, json, tracker, getToken, appdata = require("coro-http"), require("json"), require("./lua/api/tracker"), require("./lua/token").getToken, require("../appdata")

appdata.init({{"otmvideos.dat"},{"player_download/"},{"player_download/ytdl.conf",[[-x
-audio-format "wav"
-o %LOCALAPPDATA%/Local/benbebot/player_download/nil_file]]}})

local m = {}

function m.getSchoolAnnouncements()
	local resp = {status = "NOT SET", data = nil}

	if tracker.youtube() <= (100) / 24 then
		local tmpfile = appdata.get("otmvideos.dat", "a+")
		local otmVideos = tmpfile:read("*a")
		
		tracker.youtube( 1 )
		local success, result = http.request("GET", "https://www.googleapis.com/youtube/v3/search?key=" .. getToken( 3 ) .. "&channelId=UCxp1l0VLqE7yWUqmYbAuCxQ&part=id&order=date&maxResults=5")
		local data = json.parse(result)
		if not (success.code == 200 and data.items) then resp.status = "ERROR" resp.data = data return resp end
		data = data.items
		
		local append, successful, announcements = "", false, {}
		for i = #data, 1, -1 do
			local v = data[i]				
			if v.id.kind == "youtube#video" then
				local continue = otmVideos:match(v.id.videoId:gsub("%-", "%%%-")) == nil
				if continue then
					successful = true
					append = append .. "\t" .. v.id.videoId
					table.insert(announcements, v.id.videoId)
				end
			end
		end
		tmpfile:write(append)
		tmpfile:close()
		resp.status = "OK"
		resp.data = announcements
		return resp
	else
		resp.status = "ERROR"
		resp.data = "Youtube API max hourly usage exeeded"
		return resp
	end
end

function m.randomVideo()
	local resp = {status = "NOT SET", data = nil}

	local success, result = http.request("GET", "https://petittube.com/")
	if success.code ~= 200 then resp.status = "ERROR" resp.data = result return resp end
	
	result = result:match("<iframe%s?width=\"%d+\"%s?height=\"%d+\"%s?src=\"(.+)\"%s?frameborder=\"%d+\"%s?allowfullscreen>")
	local address = result:match("https://www.youtube.com/embed/([%w%_]+)")
	if not address then resp.status = "ERROR" resp.data = "couldn't parse petittube" return resp end
	
	resp.status = "OK"
	resp.data = address
	
	return resp
end

local function addToDatabase( id )
	
	local file = appdata.get("familyguys.db", "r+")
	
	file:seek("set", 4)
	
	local found = false
	
	repeat
		
		local r = file:read(1)
		
		if not r then break end
		
		if file:read(string.byte(r)) == id then
			
			found = true
			
			break
			
		end
		
	until not r
	
	if not found then
		
		file:write(string.pack("s1", id))
		file:seek("set", 0)
		local val = string.unpack("L", file:read(4))
		file:seek("set", 0)
		file:write(string.pack("L", val + 1))
		
	end
	
end

function m.crawl( channelID, order, titleMatch, maxLength )
	local count = 0

	local resp = {status = "NOT SET", data = nil}
	
	local success, result = http.request("GET", "https://www.googleapis.com/youtube/v3/search?key=" .. getToken( 21 ) .. "&channelId=" .. channelID .. "&part=id,snippet&order=" .. order .. "&maxResults=50")
	local data = json.parse(result)
	if not (success.code == 200 and data.items) then resp.status = "ERROR" resp.data = data return resp end
	
	local nextPage, items = data.nextPageToken, data.items
	
	for _=1,math.floor( data.pageInfo.totalResults / data.pageInfo.resultsPerPage ) - 1 do
		
		local success, result = http.request("GET", "https://www.googleapis.com/youtube/v3/search?key=" .. getToken( 21 ) .. "&channelId=" .. channelID .. "&part=id,snippet&order=" .. order .. "&maxResults=50" .. (nextPage and "&pageToken=" .. nextPage or ""))
		local data = json.parse(result)
		if not (success.code == 200) then resp.status = "ERROR" resp.data = result return resp end
		
		nextPage, items = data.nextPageToken, data.items
		
		for _,item in ipairs(items) do
		
			if item.snippet.title:lower():match(titleMatch) then
			
				local success, result = http.request("GET", "https://www.googleapis.com/youtube/v3/videos?key=" .. getToken( 21 ) .. "&id=" .. item.id.videoId .. "&part=contentDetails")
				local data = json.parse(result)
				if not (success.code == 200) then resp.status = "ERROR" resp.data = data return resp end
			
				local year, month, week, day, hour, minute, second = data.items[1].contentDetails.duration:match("^P(%d*)Y?(%d*)M?(%d*)W?(%d*)D?T(%d*)H?(%d*)M?(%d*)S?$") 
				year, month, week, day, hour, minute, second = tonumber(year) or 0, tonumber(month) or 0, tonumber(week) or 0, tonumber(day) or 0, tonumber(hour) or 0, tonumber(minute) or 0, tonumber(second) or 0
			
				if year * 3.154e+7 + month * 2.628e+6 + week * 604800 + day * 86400 + hour * 3600 + minute * 60 + second < maxLength then
					
					addToDatabase( item.id.videoId )
					
					count = count + 1
					
				end
			
				table.remove(items, index)
			
			else
			
				table.remove(items, index)
			
			end
			
		end
		
	end
	
	resp.status = "OK" 
	resp.data = count
	return resp
	
end

return m