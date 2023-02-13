local m = {}

function m.getToken( index )
	index = index
	local token = io.lines("token")
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