local http, pathLib, url = require("coro-http"), require("path"), require("url")

local SUCCESS = {{"Content-Length", "0"},{"Connection", "close"}, code = 200, reason = "OK"}
local NO_CONTENT = {{"Connection", "close"}, code = 204, reason = "No Content"}
local BAD_ERROR = {{"Content-Length", "0"},{"Content-Type","text/plain"},{"Connection", "close"}, code = 400, reason = "Bad Request"}
local NOT_FOUND_ERROR = {{"Connection", "close"}, code = 404, reason = "Not Found"}
local METHOD_ERROR = {{"Connection", "close"}, code = 405, reason = "Method Not Allowed"}
local INTERNAL_ERROR = {{"Content-Length", "0"},{"Content-Type","text/plain"},{"Connection", "close"}, code = 500, reason = "Internal Server Error"}

local server = {}
server.__index = server

function server:on(path, func, options)
	options = options or {}
	options.path = path options.func = func
	table.insert(rawget(self, "callbacks"), options)
end

function server:autoRespond(path, code, headers, body)
	headers.code = code
	code = nil
	self:on(path, function()
		return headers, body
	end)
end

local requestObj = {}
server.request = requestObj
requestObj.__index = function(self, index)
	return index == "body" and self.body or requestObj.req[index] or self[index]
end

function requestObj.new(req, body)
	local processed = url.parse(req.path, true)
	req.pathname = processed.pathname
	req.query = processed.query
	
	return setmetatable({req = req, body = body}, requestObj)
	
end

function requestObj:getHeader(...)
	local tofind = {...}
	local headers = {}
	for _,v in ipairs(self.req) do
		for i,k in ipairs(tofind) do
			if k == v[1] then
				headers[i] = v[2]
				break
			end
		end
	end
	return unpack(headers)
end

function requestObj:unpack()
	return self.req, self.body
end

function server:process(req, body)
	req = requestObj.new(req, body)
	
	local path, callback = req.pathname
	for _,cb in ipairs(rawget(self, "callbacks")) do
		if cb.path == path then
			callback = cb
			break
		end
	end
	if not callback then return NOT_FOUND_ERROR end
	if callback.method then
		local validMethod = false
		for _,v in ipairs(callback.method) do if req.method == v then validMethod = true break end end
		if not validMethod then return METHOD_ERROR, "" end
	end
	
	local results = {pcall(callback.func, req)}
	if not results[1] then
		INTERNAL_ERROR[1][2] = tostring(#results[2])
		return INTERNAL_ERROR, results[2]
	end
	
	local retReq, retBody = results[2], results[3]
	if not retReq then
		if retReq == false then
			BAD_ERROR[1][2] = tostring(#retBody)
			return BAD_ERROR, retBody
		end
		if retBody then
			SUCCESS[1][2] = tostring(#retBody)
			return SUCCESS, retBody
		end
		return NO_CONTENT
	end
	if retBody and not req:getHeader("Content-Length") then
		table.insert()
		server.addHeader(retReq, "Content-Length", #retBody)
	end
	
	return retReq, retBody
end

function server:start()
	local success, err = pcall(http.createServer, rawget(self, "host"), rawget(self, "port"), function(...) return self:process(...) end)
	if not success then return false, err end
	rawset(self, "tcp", err)
	return true
end

function server:stop()
	local tcp = rawget(self, "tcp")
	if not tcp then return end
	
	return tcp
end

function server.new(host, port)
	if type(host) == "table" then
		host = rawget(host, "ip")
	end
	
	return setmetatable({host = host, port = port, callbacks = {}}, server)
end

function server.addHeader(req, name, value)
	table.insert(req, 1, {tostring(name), tostring(value)})
end

return server