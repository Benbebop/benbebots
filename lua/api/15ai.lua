local http, json, appdata = require("coro-http"), require("json"), require("../appdata")

appdata.init({{"15ai\\"}})

local ai = {}

-- yo shout out my man https://github.com/wafflecomposite/15.ai-Python-API

local file = io.open("tables/15aiCharacterIndex.json", "r")

local characterIndex = json.parse(file:read("*a"))

file:close()

local max_text_len = 500

local tts_headers = {
	{"accept", "application/json, text/plain, */*"},
	{"accept-encoding","gzip, deflate, br"},
	{"accept-language","en-US,en;q=0.9"},
	{"access-control-allow-origin","*"},
	{"content-type","application/json;charset=UTF-8"},
	{"origin","null"},
	{"referer","https://github.com/Benbebop/Benbebot"},
	{"sec-fetch-dest","empty"},
	{"sec-fetch-mode","cors"},
	{"sec-fetch-site","same-site"},
	{"user-agent","Benbebot/1.0 (https://github.com/Benbebop/Benbebot)"}
}

local tts_url, audio_url = "https://api.15.ai/app/getAudioFile5", "https://cdn.15.ai/audio/"

function ai.getCharacter( str )
	if not str then
		local c = {}
		for _,v in ipairs(characterIndex) do
			if not v.banned then
				if not c[v.category] then c[v.category] = "" end
				c[v.category] = c[v.category] .. v.name .. ", "
			end
		end
		return c
	else
		str = str:gsub("%s", "")
		local banned, exists = false, false
		for _,v in ipairs(characterIndex) do
			for _,m in ipairs(v.match) do
				if str:match(m) then
					exists = v
					if v.banned then banned = true break end
				end
			end
			if banned then break end
		end
		if banned then
			return false, exists.name
		elseif exists then
			return exists.name
		else
			return nil
		end
	end
end

function ai.getTTSRaw(character, text)

	local resp = {status = "NOT SET", data = nil}

	if #text > max_text_len then
		text = text:sub(1, max_text_len - 1)
	end
	
	if not (text:match("%.$") or text:match("%!$") or text:match("%?$")) then
		if #text < 140 then
			text = text .. "."
		else
			text = text .. "."
		end
	end
	
	local payload = json.stringify({text = text, character = character, emotion = "Contextual"})
	
	local success, result = http.request("POST", tts_url, tts_headers, payload)
	
	result = json.parse(result)
	
	if success.code == 200 and result["wavNames"] then
		
		local audio_uri = result["wavNames"][1]
		
		local success, responseAudio = http.request("GET", audio_url .. audio_uri, tts_headers)
		
		if success.code ~= 200 then resp.status = "15ai Error (" .. success.reason .. ")" return resp end
		
		resp.status = "OK"
        resp.data = responseAudio
		
		return resp
	else
		resp.status = "15ai Error (" .. success.reason .. ")"
		return resp
	end
end

function ai.saveToFile(character, text, filename)
	local tts = ai.getTTSRaw(character, text)
	if tts.status == "OK" and tts.data ~= nil then
		if not filename then
			-- i have no idea what any of that means
		end
		if not filename:match("%.wav$") then
			filename = filename .. ".wav"
		end
		f = appdata.get( "15ai\\" .. filename, "wb")
		f:write(tts.data)
		f:close()
		return {status = tts.status, filename = appdata.directory() .. "15ai\\" .. filename}
	else
		return {status = tts.status, filename = nil}
	end
end

return ai