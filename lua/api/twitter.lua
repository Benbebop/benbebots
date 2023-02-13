local http, json, tracker, getToken, appdata = require("coro-http"), require("json"), require("./lua/api/tracker"), require("./lua/token").getToken, require("../appdata")

local t = {}

function t.getIdByUsername( username )
	local success, result = http.request("GET", "https://api.twitter.com/2/users/by/username/" .. username, {{"Authorization", "Bearer " .. getToken( 7 )}})
	if success then
		return json.parse(result).id
	end
end

function t.getFurryArt()
	
end

return t