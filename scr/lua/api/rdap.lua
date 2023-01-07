local http, json = require("coro-http"), require("json")

local rdap = {}

function rdap.fetchIp( ip )
	local header, body = http.request("get", "https://rdap.arin.net/registry/ip/" .. ip)
			
	if header.code ~= 200 or not body then return false, header.code end
	
	local results = json.parse(body)
	
	return true, {
		handle = results.handle,
		startAddress = results.startAddress, endAddress = results.endAddress
		ipVersion = results.ipVersion,
		name = results.name, parentHandle = results.parentHandle,
		status = results.status[0]
	}
	
end

function rdap.ipExists( ip )
	
	local success, result = rdap.fetchIp( ip )
	
	return success and result.status == "reserved"
	
end

return rdap