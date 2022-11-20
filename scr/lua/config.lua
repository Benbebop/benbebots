local appdata, json = require("./appdata"), require("json")

_G.config = _G.config or {}

local typeIndex = {"b", "B", "h", "H", "l", "L", "j", "J", "T", "f", "d", "n", "z", "s2", "B"}

local cfg = {}

function cfg.update()
	local file = io.open( "resource/config-update.json", "rb" ) local update = json.parse( file:read( "*a" ) ) file:close()
	for i,v in pairs(_G.config) do
		if not update[i] then _G.config[i] = nil end
	end
	for i,v in pairs(update) do
		if not _G.config[i] then _G.config[i] = v end
	end
end

function cfg.load()
	local file = appdata.get( "global.lcfg", "rb" )
	if not file then cfg.update() else
		local nxt = file:read(1)
		repeat
			nxt = string.unpack("B", nxt)
			local i = file:read( nxt )
			local t = string.unpack("B", file:read(1))
			local v
			if t == 15 then
				v = string.unpack(typeIndex[t], file:read(1))
				v = v > 0
			elseif t == 14 then
				v = file:read( string.unpack("B", file:read(1)) )
			else
				v = file:read( string.unpack(typeIndex[t], file:read(8)) )
			end
			_G.config[i] = v
			nxt = file:read(1)
		until not nxt
		file:close()
	end
end

function cfg.save()
	local file = appdata.get( "global.lcfg", "wb" )
	for i,v in pairs(_G.config) do
		local t = type(v)
		if t == "boolean" then
			t = 15
			v = v and 1 or 0
		elseif t == "string" then
			t = 14
		elseif t == "number" then
			if math.floor(v) == v then
				t = 7
			else
				t = 12
			end
		else
			t = nil
		end
		if t then file:write( string.pack("s1B" .. typeIndex[t], i, t, v) ) end
	end
	file:close()
end

return cfg