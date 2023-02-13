local appdata = require("../appdata")

appdata.init({{"langton/"},{"langton/ant.dat", ""}})

local lt = {}

local part_size = 15
local render_depth = 255
local bindex = {["0"] = "0000", ["1"] = "0001", ["2"] = "0010", ["3"] = "0011", ["4"] = "0100", ["5"] = "0101", ["6"] = "0110", ["7"] = "0111", ["8"] = "1000", ["9"] = "1001", ["A"] = "1010", ["B"] = "1011", ["C"] = "1100", ["D"] = "1101", ["E"] = "1110", ["nul"] = "1111"}

local function bintodec( n ) return tonumber( n, 2 ) end

local function dectobin( n )
    local t = {}  
    for b = 8, 1, -1 do
        t[b] = math.fmod(n, 2)
        n = math.floor((n - t[b]) / 2)
    end
	local str = ""
	for _,v in ipairs(t) do str = str .. v end
    return str
end

local function hextodec( n ) return tonumber( n, 14 ) end

local hexdex = {[0] = "0", [1] = "1", [2] = "2", [3] = "3", [4] = "4", [5] = "5", [6] = "6", [7] = "7", [8] = "8", [9] = "9", [10] = "A", [11] = "B", [12] = "C", [13] = "D", [14] = "E"}

local function dectohex( n )
	return hexdex[n]
end

local function writePart( x, y, content )
	x, y, content = tonumber(x) or 0, tonumber(y) or 0, tostring(content)
	
	local bytes = {}
	local itterations = 0
	for c in content:gmatch(".") do
		itterations = itterations + 1
		local b = bindex[c]
		if not b then error("malformed part data (" .. c .. ")") end
		table.insert(bytes, b)
	end
	
	local str = ""
	for i=2,math.ceil( #bytes / 2 ) * 2,2 do
		local v2, v1 = bytes[i] or "1111", bytes[i - 1] or "1111"
		str = str .. string.char(bintodec(v1 .. v2))
	end
	
	local part = appdata.get("langton/" .. x .. "_" .. y .. ".prt", "wb")
	part:write(str)
	part:close()
	
	return str
end

local function readPart( x, y )
	x, y = tonumber(x) or 0, tonumber(y) or 0
	local part = appdata.get("langton/" .. x .. "_" .. y .. ".prt", "rb")
	
	if not part then 
		writePart( x, y, string.rep("0", part_size ^ 2) ) 
		part = appdata.get("langton/" .. x .. "_" .. y .. ".prt", "rb")
	end
	
	local bytes = {}
	for c in (part:read("*a") or string.rep("0", part_size ^ 2)):gmatch(".") do
		local bin = dectobin(string.byte(c))
		table.insert(bytes, bin:sub(1, 4))
		table.insert(bytes, bin:sub(5, 8))
	end
	
	local str = ""
	for _,v in ipairs(bytes) do
		for i,k in pairs(bindex) do
			if i == "nul" then i = "" end
			if v == k then str = str .. i end
		end
	end
	
	return str
end

local function getAntSettings()
	local f = appdata.get("langton/ant.dat", "r")
	local data = f:lines()
	local settings = {}
	local p = {}
	settings.patternstr = data()
	for c in settings.patternstr:gmatch(".") do
		table.insert(p, c)
	end
	settings.pattern = p
	local x, y = data():match("(%-?%d+)%s+(%-?%d+)")
	settings.position = {x = tonumber(x), y = tonumber(y)}
	x, y = data():match("(%-?%d+)%s+(%-?%d+)")
	settings.direction = {x = tonumber(x), y = tonumber(y)}
	settings.itteration = tonumber(data())
	f:close()
	return settings
end

local function saveAntSettings( settings )
	local pre = getAntSettings()
	local f = appdata.get("langton/ant.dat", "w")
	local pstr = ""
	for _,v in ipairs(settings.pattern) do
		pstr = pstr .. v
	end
	f:write(pstr)
	f:write("\n", (settings.position.x or pre.pattern.x), " ", (settings.position.y or pre.pattern.y))
	f:write("\n", (settings.direction.x or pre.direction.x), " ", (settings.direction.y or pre.direction.y))
	f:write("\n", tostring( settings.itteration ))
	f:close()
end

local function toMatrix( data )
	local matrix, i = {}, 0
	local str
	for y=1,part_size do
		for x=1,part_size do
			if not matrix[x] then matrix[x] = {} end
			local index = (y - 1) * part_size + x
			matrix[x][y] = hextodec(data:sub(index, index) or 0)
		end
	end
	-- for v in data:gmatch(".") do
		-- local major, minor = i % part_size, math.floor( i / part_size )
		-- if not matrix[major] then matrix[major] = {} end
		-- matrix[major][minor] = hextodec( v )
		-- i = i + 1
	-- end
	return matrix
end

local function fromMatrix( matrix )
	matrix = matrix or {}
	local str = ""
	for y=1,part_size do
		for x=1,part_size do
			str = str .. dectohex((matrix[x] or {})[y] or 0)
		end
	end
	return str
end

--[[
	deletes all data and starts a new pattern
]]
function lt.reset( pattern )
	pattern = tostring( pattern ) or "RL"
	
	if #pattern < 2 then error("pattern too short") end
	
	for c in pattern:gmatch(".") do
		if c == "R" then
		elseif c == "L" then
		else
			error("malformed pattern (" .. c .. ")")
		end
	end
	
	local defaultpos = math.ceil( part_size / 2 )
	
	local new = appdata.get("langton/ant.dat", "w")
	new:write(pattern) -- pattern
	new:write("\n" .. defaultpos .. " " .. defaultpos) -- position
	new:write("\n0 1") -- direction
	new:write("\n0") -- itteration
	new:close()
	
	writePart( 0, 0, fromMatrix() )
end

--[[
	writes directly to a part
]]
lt.write = writePart

--[[
	reads directly from a part
]]
lt.read = readPart

--[[
	move the ant forward
]]
function lt.step()
	local ant = getAntSettings()
	local partCord = {x = math.floor( ant.position.x / part_size ), y = math.floor( ant.position.y / part_size )}
	local localCord = {x = (ant.position.x % part_size) + 1, y = (ant.position.y % part_size) + 1}
	local part = toMatrix(readPart( partCord.x, partCord.y ))
	print(localCord.x)
	local pindex, actuallindex = (part[localCord.x][localCord.y] or -1) + 1, 0
	if ant.pattern[pindex + 1] then
		actuallindex = pindex
	else
		actuallindex = 0
	end
	local toTurn = ant.pattern[actuallindex + 1]
	if toTurn == "R" then -- rotate clockwise
		ant.direction = {x = ant.direction.y, y = -ant.direction.x}
	elseif toTurn == "L" then -- rotate counter-clockwise
		ant.direction = {x = -ant.direction.y, y = ant.direction.x}
	else
		error("could not index pattern (" .. actuallindex + 1 .. ")")
	end
	ant.position.x = ant.position.x + ant.direction.x
	ant.position.y = ant.position.y + ant.direction.y
	ant.itteration = ant.itteration + 1
	saveAntSettings( ant )
	part[localCord.x][localCord.y] = actuallindex
	writePart( partCord.x, partCord.y, fromMatrix(part) )
end

local directionIndicator = {["0 1"] = "^", ["1 0"] = ">", ["0 -1"] = "V", ["-1 0"] = "<"}

--[[
	turns part into text block (developer dont use in final product)
]]
function lt.ascii()
	local ant = getAntSettings()
	local partCord = {x = math.floor( ant.position.x / part_size ), y = math.floor( ant.position.y / part_size )}
	local localCord = {x = ant.position.x % part_size, y = ant.position.y % part_size}
	local part = readPart( partCord.x, partCord.y )
	local i = 0
	local prt = ""
	for c in part:gmatch(".") do
		i = i + 1
		if i == localCord.y * part_size + localCord.x then
			prt = prt .. directionIndicator[ant.direction.x .. " " .. ant.direction.y]
		else
			prt = prt .. c
		end
		if i % part_size == 0 then
			prt = prt .. "\n"
		end
	end
	prt = partCord.x .. "_" .. partCord.y .. "\n" .. prt
	return prt
end

--[[
	renders a ppm of the current pattern
]]
function lt.render( width, height, depth )
	
end

--[[
	gets the state of the current pattern
]]
lt.state = getAntSettings

return lt