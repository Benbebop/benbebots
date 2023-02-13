local http, https, json = require("coro-http"), require("https"), require("json")

local w = {}

local function createHeader( payload, content_type, connection, code, reason )
	content_type = content_type or "text/plain"
	connection = connection or "close"
	code = code or 500
	if code == 200 then reason = "" end
	reason = reason or "idk"
	local result = {
		{"Content-Type", content_type}, -- Type of the response's payload (res_payload)
		{"Connection", connection}, -- Whether to keep the connection alive, or close it
		code = code,
		reason = reason,
	}
	if payload then
		result[3] = {"Content-Length", #payload}
	end
	return result
end

function w.create(host, port, callback, icon)
	host, port = host or "0.0.0.0", port or 8080
	http.createServer(host, port, function( headers, body, tcp )
		if headers.path:sub(1, 12) == "/favicon.ico" then
			if icon then
				local file = io.open(icon, "rb")
				if not file then return createHeader("", nil, nil, 500, "Internal Server Error"), "" end
				local s = file:read("*a")
				file:close()
				return createHeader(s, nil, nil, 200), s
			end
			return createHeader("", nil, nil, 404, "File Not Found"), ""
		else
			local h, i = {}, 1
			while headers[i] do
				h[headers[i][1]] = headers[i][2]
				headers[i] = nil
				i = i + 1
			end
			headers.pathfull = headers.path
			local path, paramstr = headers.path:match("([^%?]+)%??([^%?]*)")
			headers.path = path
			headers.parameters = {}
			for param in (paramstr or ""):gmatch("([^&]+)") do
				local index, val = param:match("([^=]+)=?([^=]+)")
				headers.parameters[index] = val
			end
			local headers, payload, code, reason, content_type, connection = callback( headers, h, body, tcp )
			if not payload then payload = "" end
			if (not headers) or type(headers) ~= "table" then 
				headers = createHeader(payload, content_type, connection, code, reason) 
			else
				headers.code = code or 500
				headers.reason = reason or "idk"
			end
			return headers, payload
		end
	end)
end

function w.createSecure(host, port, callback, icon)
	host, port = host or "0.0.0.0", port or 8080
	https.createServer(host, port, function( headers, body, tcp )
		if headers.path:sub(1, 12) == "/favicon.ico" then
			if icon then
				local file = io.open(icon, "rb")
				if not file then return createHeader("", nil, nil, 500, "Internal Server Error"), "" end
				local s = file:read("*a")
				file:close()
				return createHeader(s, nil, nil, 200), s
			end
			return createHeader("", nil, nil, 404, "File Not Found"), ""
		else
			local h, i = {}, 1
			while headers[i] do
				h[headers[i][1]] = headers[i][2]
				headers[i] = nil
				i = i + 1
			end
			headers.pathfull = headers.path
			local path, paramstr = headers.path:match("([^%?]+)%??([^%?]*)")
			headers.path = path
			headers.parameters = {}
			for param in (paramstr or ""):gmatch("([^&]+)") do
				local index, val = param:match("([^=]+)=?([^=]+)")
				headers.parameters[index] = val
			end
			local headers, payload, code, reason, content_type, connection = callback( headers, h, body, tcp )
			if not payload then payload = "" end
			if (not headers) or type(headers) ~= "table" then 
				headers = createHeader(payload, content_type, connection, code, reason) 
			else
				headers.code = code or 500
				headers.reason = reason or "idk"
			end
			return headers, payload
		end
	end)
end

return w