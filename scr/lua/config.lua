local appdata, json, fs, uv = require("./appdata"), require("json"), require("fs"), require("uv")

local typeIndex = {"B", "B", "H", "H", "L", "L", "I8", "I8", "j", "J", "T", "f", "d", "n", "z", "s2", "B"}

local config, sub_config = {}, {}

local function subMeta( path, defaults ) return {file = path, config = {}, defaults = defaults or {}, immediate = uv.new_timer()} end

function config.new( self, guild )
	local sub = setmetatable( subMeta( rawget( self, "dir" ) .. guild .. ".lcfg", rawget( self, "defaults" ).config ), sub_config )
	sub:save()
	rawget( self, "configs" )[guild] = sub
	return sub
end

function config.get( self, guild )
	local configs = rawget( self, "configs" )
	if guild == "default" or guild == "_default" then
		return nil
	elseif configs[index] then
		return configs[index]
	else
		local sub = setmetatable( subMeta( rawget( self, "dir" ) .. guild .. ".lcfg", rawget( self, "defaults" ).config ), sub_config )
		if sub:load() then
			configs[guild] = sub
			return sub
		end
	end
end

function config.getAll( self, index )
	local results = {}
	for i,v in pairs(rawget( self, "configs" )) do
		results[i] = rawget( v, config )[index]
	end
	return results
end

function config.getAllArray( self, index )
	local results = {}
	for i,v in pairs(rawget( self, "configs" )) do
		table.insert( results, rawget( v, config )[index] )
	end
	return results
end

function config.load( self )
	local dir = rawget( self, "dir" )
	for f,t in fs.scandirSync( dir ) do
		if t == "file" and f:sub(-5, -1) == ".lcfg" then
			local sub = setmetatable( subMeta( dir .. f, rawget( self, "defaults" ).config ), sub_config )
			if sub:load() then
				local configs = rawget( self, "configs" )
				local name = f:sub(1, -6)
				if name == "_default" then
					configs["0"] = sub
				else
					configs[name] = sub
				end
			end
		end
	end
end

local version = string.pack("H", 1)

function sub_config.load( self )
	local file = rawget( self, "file" )
	local fd = fs.openSync(file, "r")
	if not fd then return {} end
	if fs.readSync(fd, 4, 0) ~= "LCFG" then return nil end
	if fs.readSync(fd, 2, 4) ~= version then return nil end
	fs.closeSync(fd) local str = fs.readFileSync(file)
	local len, cursor, tbl = #str, 7, {}
	while cursor < len do
		local l = string.unpack("B", str:sub(cursor, cursor)) cursor = cursor + 1
		local index = str:sub(cursor, cursor + l - 1) cursor = cursor + l
		local packIndex = string.unpack("B", str:sub(cursor, cursor)) cursor = cursor + 1
		local packStr = typeIndex[packIndex]
		
		local sign = packIndex <= 8 and ((packIndex % 2) == 0 and 1 or -1)
		
		if packIndex == 0 then
		elseif packIndex <= 2 then
			tbl[index] = string.unpack(packStr, str:sub(cursor, cursor)) * sign cursor = cursor + 1
		elseif packIndex <= 4 then
			tbl[index] = string.unpack(packStr, str:sub(cursor, cursor + 1)) * sign cursor = cursor + 2
		elseif packIndex <= 6 then
			tbl[index] = string.unpack(packStr, str:sub(cursor, cursor + 3)) * sign cursor = cursor + 4
		elseif packIndex <= 8 then
			tbl[index] = string.unpack(packStr, str:sub(cursor, cursor + 7)) * sign cursor = cursor + 8
		elseif packIndex == 13 then
			tbl[index] = string.unpack(packStr, str:sub(cursor, cursor + 7)) cursor = cursor + 8
		elseif packIndex == 16 then
			local len = string.unpack("H", str:sub(cursor, cursor + 1)) cursor = cursor + 2
			tbl[index] = str:sub(cursor, cursor + len - 1) cursor = cursor + len
		elseif packIndex == 17 then
			tbl[index] = string.unpack(packStr, str:sub(cursor, cursor)) == 1 cursor = cursor + 1
		end
	end
	rawset( self, "config", tbl )
	return true
end

function config.save( self )
	for _,v in ipairs(rawget( self, "configs" )) do
		v:save()
	end
end

function sub_config.save( self )
	(rawget( self, "immediate" ) or uv.new_timer()):stop()
	local str = {string.pack("c4c2", "LCFG", version)}
	for i,v in pairs(rawget( self, "config" )) do
		table.insert(str, string.pack("s1", i))
		local packIndex = 0
		if type(v) == "number" then
			if math.floor(v) ~= v then
				if v < 256 then
					packIndex = 2
				elseif v < 65536 then
					packIndex = 4
				elseif v < 4294967296 then
					packIndex = 6
				else
					packIndex = 8
				end
				if v > 0 then packIndex = packIndex - 1 end
				v = math.abs(v)
			else
				packIndex = 13
			end
		elseif type(v) == "string" then
			packIndex = 16
		elseif type(v) == "boolean" then
			packIndex = 17
			v = v and 1 or 0
		elseif type(v) == "nil" then
			packIndex = 0
		end
		table.insert(str, string.pack("B" .. (typeIndex[packIndex] or ""), packIndex, v))
	end
	fs.writeFileSync(rawget( self, "file" ), table.concat(str))
end

function config.setDefaults( self, set )
	local defaults = rawget( self, "defaults" )
	defaults.config = set
	sub_config.save( defaults )
end

config.__index = function( self, index )
	if tonumber( index ) then
		local config = config.get( self, index )
		if not config then
			config = config.new( self, index )
		end
		return config
	else
		return config[index]
	end
end

sub_config.__index = function( self, index )
	return sub_config[index] or rawget( self, "config" )[index] or rawget( self, "defaults" )[index]
end

sub_config.__newindex = function( self, index, value )
	rawget( self, "config" )[index] = value
	local immediate = rawget( self, "immediate" )
	immediate:stop()
	immediate:start( 0, 0, function()
		sub_config.save( self )
	end)
end

return function( append )
	
	local dir = "configs-" .. append .. "/"
	
	appdata.init({{dir},{dir .. "_default.lcfg", string.pack("c4c2", "LCFG", version)}})
	
	dir = appdata.path( dir )
	
	_G.config = _G.config or setmetatable({dir = dir, configs = {}}, config)
	
	local default = {file = dir .. "_default.lcfg"}
	sub_config.load( default )
	
	rawset(_G.config, "defaults", default)
	
	_G.config:load()
	
	return _G.config
	
end