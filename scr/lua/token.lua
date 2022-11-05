local encoder = require("./encoder")

local m = {}

local function readToken()
	local token = io.open("token", "rb")
	local str = encoder.decodetext(token:read("*a"))
	token:close()
	return str:gmatch("(.-)\n")
end

function m.getToken( index )
	index = index
	local token = readToken()
	local ftoken = ""
	for i=1,index do
		ftoken = token()
	end
	return ftoken:match("([^%s]+)%s*//")
end

function m.clashToken()
	local tFile = io.open("tables/jwt_token.dat", "r") local tData = tFile:read("*a") tFile:close()
	
	local source = tData:match("source\t(.-)\n")
	
	local header = {
		{"typ", tData:match("typ\t(.-)\n")},
		{"alg", tData:match("alg\t(.-)\n")},
		{"kid", tData:match("kid\t(.-)\n")}
	}
	
	local payload = tData:match("payload\t(.-)%s*$")
	
	return header, payload, source
end

return m