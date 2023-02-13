local http, json, tracker, getToken = require("coro-http"), require("json"), require("./lua/api/tracker"), require("./lua/token").getToken

local m = {}

function m.getDefinition( toDefine )
	local resp = {status = "NOT SET", data = nil}
	
	if tracker.webster() <= (1000) / 24 and toDefine then
		tracker.webster( 1 )
		local success, result = http.request("GET", "https://dictionaryapi.com/api/v3/references/collegiate/json/" .. toDefine:lower() .. "?key=" .. getToken( 4 ))
		local data, found = json.parse(result), false
		if success.code ~= 200 then resp.status = "ERROR" resp.data = result return resp end
		
		local fields, title = {}, "Websters Dictionary | " .. tracker.webster() .. "/" .. math.floor((1000) / 24)
		if data and toDefine then
			for i,v in ipairs(data) do
				if type(v) == "table" then
					found = true
					local word = "	**" .. v.meta.id:gsub("%:?%d*$", "") .. "**"
					if v.meta.offensive then --:face_with_symbols_over_mouth:
						word = word .. " :face_with_symbols_over_mouth:"
					end
					local definition = ""
					for l,k in ipairs(v.shortdef) do
						definition = definition .. l .. ": " .. k .. "\n"
					end
					table.insert(fields, {name = word, value = definition, inline = false})
				else
					table.insert(fields, {name = word, value = "", inline = false})
				end
			end
			resp.status = "OK"
			resp.data = {fields, found, title}
			return resp
		elseif toDefine then
			resp.status = "OK"
			resp.data = {toDefine, found, title}
			return resp
		end
	else
		resp.status = "ERROR"
		return resp
	end
end

return m