local http, querystring, urlParse = require("coro-http"), require("querystring"), require("url").parse

local yt = {}
yt.__index = yt

function yt.new(key)
	
	return setmetatable({key = key}, yt)
	
end

function yt.parseUrl(url)
	
	return urlParse(url).path
	
end

function yt:request(method, endpoint, query, headers, body)
	query = query or {}
	query.key = rawget(self, "key")
	
	local res, body = http.request(method or "GET", string.format("https://youtube.googleapis.com/youtube/v%d/%s?%s", 3, endpoint, querystring.stringify(query)), headers, body)
	
	return res, body
end

return yt