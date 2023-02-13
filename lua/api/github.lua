local http, json, appdata = require("coro-http"), require("json"), require("../appdata")

local m = {}

function m.applyMotd()
	initFile = io.open("scBackup.txt", "wb")
	local success, result = http.request("GET", "https://raw.githubusercontent.com/Benbebop/Benbebot/main/scBackup.txt")
	initFile:write(result)
	initFile:close()
end

appdata.init({{"release.txt"}})

function m.release()
	local success, result = http.request("GET", "https://api.github.com/repos/benbebop/benbebot/releases/latest", {{"User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:99.0) Gecko/20100101 Firefox/99.0"}})
	if success.code == 200 then
		result = json.parse(result)
		if result.id ~= tonumber(appdata.read("git-release.id")) then
			appdata.write("git-release.id", result.id)
			local context = false
			for _,v in ipairs(result.assets) do
				if v.name == "bot_release_context.json" then
					context = v.browser_download_url
					break
				end
			end
			success, result = http.request("GET", context)
			if success.code == 200 then
				return result
			end
		end
	end
end

return m