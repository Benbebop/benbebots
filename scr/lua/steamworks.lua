local ffi = require("ffi")

local binds

do
	local fs, json = require("fs"), require("json")
	
	ffi.cdef(fs.readFileSync("bin/steam_api_flat.h"))
	
	binds = json.parse(fs.readFileSync("bin/steam_api.json"))
	
	fs.writeFileSync("steam_appid.txt", "4000")
	
end

if jit.os == "Windows" then
	if jit.arch == "x64" then
		lib = ffi.load("bin/steam_api64")
	elseif jit.arch == "x86" then
		lib = ffi.load("bin/steam_api")
	end
else
	lib = ffi.load("libsteam_api")
end

local steamworks = {}

local function parseValue( value )
	return tonumber( value ) or value
end

-- callback consts

-- consts

-- enums

steamworks.enums = {}

for _,enumData in ipairs(binds.enums) do
	local enum = {}
	for _,value in ipairs(enumData.values) do
		enum[value.name] = parseValue( value.value )
	end
	steamworks.enums[enumData.enumname] = enum
end

-- interfaces

for _,classData in ipairs(binds.interfaces) do
	local class = {}
	for _,method in ipairs(classData.methods) do
		class[method.methodname] = function( ... )
			return lib[method.methodname_flat]( ... )
		end
	end
	steamworks[classData.classname] = class
end