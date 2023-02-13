local http, json, appdata = require("coro-http"), require("json"), require("../appdata")

local g = {}

g.supportedImages = {bmp = true, gif = true, jpeg = true, png = true, webp = true, svg = false}

function g.reverseSearch( url )
	local resp = {status = "NOT SET", data = nil}
	
	local status, result = http.request("GET", "https://images.google.com/searchbyimage?image_url=" .. url, {{"Content-length", 0}})
	if status.code ~= 200 then resp.status = "ERROR" resp.data = result return resp end
	
	resp.status = "OK"
	resp.data = result
	return resp
end

return g