local b = {}

function b.createHeader( str )
	local headers = {}
	for s in str:gmatch("(.-)\n") do
		table.insert(headers, {s:match("^(.-):%s?"), s:match(":%s?(.-)$")})
	end
	return headers
end

return b