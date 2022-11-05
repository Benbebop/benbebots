local net, http = require("net"), require("coro-http")

--[[local defaultOptions = {method = "GET", protocol = "https:", host = "soap2day.to"}

local function getPage( path, callback )
	local defaultOptions = defaultOptions
	defaultOptions.path = path
	
	return http.request( defaultOptions, callback )
	
end]]

local s2d = {}

function s2d.downloadMedia( mediaPage )
	
	p(http.request("GET", "https://soap2day.to" .. mediaPage))
	
end

return s2d