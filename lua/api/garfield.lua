local http, json, appdata = require("coro-http"), require("json"), require("../appdata")

local strips = {}

local g = {}

function g.getStrip( seed )
	math.randomseed( seed or os.clock() )
	
	local resp = {status = "NOT SET", data = nil}
	
	local year, month, day = 1978 + math.random(0, 44), math.random(1, 12), math.random(1, 31)
	local url, success, result = ""
	repeat
		resp.data = {url = "http://images.ucomics.com/comics/ga/" .. year .. "/ga" .. string.format("%02d%02d%02d",year % 100,month,day) .. ".gif"}
		success, result = http.request("GET", resp.data.url)
		day = day - 1
	until success.code == 200 or day < 1
	if success.code ~= 200 then resp.status = "Error (" .. result ..")" return resp end
	resp.status = "OK"
	resp.data.year, resp.data.month, resp.data.day = year, month, day + 1
	return resp
end

return g