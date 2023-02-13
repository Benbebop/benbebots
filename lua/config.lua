local appdata = require("./appdata")

local ini_file_name = "global.ini"

if args[1] == "bot-maw.lua" then
	ini_file_name = "maw.ini"
end

local function toValue(val)
	if type(val) == "string" and val:match("^[%d%.]+$") then
		return "s" .. val
	else
		return tostring(val)
	end
end

local function fromValue(str)
	if str == "true" then
		return true
	elseif str == "false" then
		return false
	elseif str == "null" then
		return nil
	elseif str:match("^s[%d%.]+$") then
		local ret = str:match("^s([%d%.]+)$")
		return ret
	elseif tonumber(str) then
		return tonumber(str)
	else
		return str
	end
end

local c = {}

function c.get()
	local tbl = {}
	local section = false
	for i in appdata.lines(ini_file_name) do
		local s = i:match("^%s*%[(.-)%]%s*$")
		local k, v = i:match("^(.-)=(.-)$")
		local comment = i:match("^;")
		if comment then
		elseif s then
			section = s
			tbl[section] = {}
		elseif not section and k and v then
			tbl[k] = fromValue(v)
		elseif k and v then
			tbl[section][k] = fromValue(v)
		end
	end
	return tbl
end

function c.checkSection(section)
	local config = appdata.get(ini_file_name, "rb")
	local exists = false
	repeat
		local p = config:read("*l")
		if p:match("^%s*%[" .. section .. "%]%s*$") then
			exists = true
		end
	until exists or not p
	config:close()
	return exists
end

function c.checkKey(section, key)
	local config = appdata.get(ini_file_name, "rb")
	local _section = false
	local exists = false
	repeat
		local p = config:read("*l")
		local s = p:match("^%s*%[(.-)%]%s*$")
		if s then
			if _section then
				break
			elseif s == section then
				_section = true
			end
		elseif p:match("^" .. key .. "=.-$") and not p:match("^;") and _section then
			exists = true
		end
	until exists or not p
	config:close()
	return exists
end

function c.checkKeyGlobal(key)
	local config = appdata.get(ini_file_name, "rb")
	local exists = false
	repeat
		local p = config:read("*l")
		if p:match("^" .. key .. "=.-$") and not p:match("^;") then
			exists = true
		end
	until exists or not p
	config:close()
	return exists
end

function c.setKey(section, key, value)
	local config = appdata.get(ini_file_name, "rb")
	local _section = false
	local str = ""
	repeat
		local p = config:read("*l")
		if p then
		local s = p:match("^%s*%[(.-)%]%s*$")
		if s then
			if _section then
				_section = false
			elseif s == section then
				_section = true
			end
		elseif _section then
			p = p:gsub("^" .. key .. "=.-$", key .. "=" .. toValue(value))
		end
		str = str .. p .. "\n"
		end
	until not p
	config:close()
	appdata.write(ini_file_name, str:gsub("\n$", ""))
end

function c.verify()
	local o = c.get()
	local v = io.open("tables/" .. ini_file_name .. ".default", "rb")
	appdata.write(ini_file_name, v:read("*a"))
	v:close()
	for section,tbl in pairs(o) do
		for key,value in pairs(tbl) do
			c.setKey(section, key, value)
		end
	end
end

return c