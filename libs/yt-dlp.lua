local uv = require("uv")

local ytdlp = {}

function ytdlp:parseUrl()
	url = urlParse(self.url) or {}
	
	if not url.host then return "invalid url" end
	
	interaction:replyDeferred(true)
		
	local query = url.query and queryString.parse( url.query )
	
	url = url.host .. url.path
	
	if query then
		url = url .. "?"
		for i,v in pairs(query) do
			if type(v) == "table" then
				for l,k in ipairs(v) do
					query[i][l] = queryString.urlencode(k)
				end
			else
				query[i] = queryString.urlencode(v)
			end
		end
		url = url .. queryString.stringify(query)
	end
	
	self.url = url
end

function ytdlp:listFormats()
	
end

return function( url, executable )
	executable = executable or "bin/yt-dlp"
	
	return setmetatable( {exe = executable, url = url}, ytdlp )
end
