-- parse the valve keyvalue data format

local controlChar = {"{", "}", "\""}
local escapeChar = {"\n", "\t", "\\", "\""}
local whiteChar = {" ", "\r", "\n", "\t"}

local escapeSequences = {n = "\n", t = "\t", ["\\"] = "\\", ["\""] = "\""}
local escapeSequencesInvert = {}
for i,v in pairs(escapeSequences) do escapeSequencesInvert[v] = i end

local function partOf(value, tbl)
	for _,v in ipairs(tbl) do
		if value == v then return true end
	end
	return false
end

function encodeString(str)
	local buffer = {}
	for i=1,#str do
		local c = str:sub(i,i)
		local e = escapeSequencesInvert[c]
		if e then
			table.insert(buffer, "\\") table.insert(buffer, e)
		else
			table.insert(buffer, c)
		end
	end
	return table.concat(buffer)
end

local function scanWhite(str, pos)
	if not pos then return end
	for i=pos,#str do
		local c = str:sub(i,i)
		if not partOf(c, whiteChar) then return i, c end
	end
	return nil
end

local function scanToken(str, pos)
	if not pos then return end
	local buffer = {}
	for i=pos,#str do
		local c = str:sub(i,i)
		if partOf(c, whiteChar) or partOf(c, controlChar) then return table.concat(buffer), i, c end
		table.insert(buffer, c)
	end
	return nil
end

local function scanString(str, pos)
	if not pos then return end
	pos = pos + 1
	local buffer, escaped = {}, false
	for i=pos,#str do
		local c = str:sub(i,i)
		if c == "\\" then
			escaped = true
		elseif (not escaped) and c == "\"" then
			return table.concat(buffer), i + 1, c
		elseif escaped then
			escaped = false
			table.insert(buffer, escapeSequences[c] or c)
		else
			table.insert(buffer, c)
		end
	end
	return nil
end

local function scanComment(str, pos)
	if not pos then return end
	local c = str:sub(pos,pos)
	if c ~= "/" then return pos, false end
	pos = pos + 1 c = str:sub(pos,pos)
	if not (c == "/" or c == "*") then return pos, c end
	for i=pos,#str do
		c = str:sub(i,i)
		if c == "\n" then return scanWhite(str, i) end
	end
	return nil
end

local kv = {}

function kv.decode(str)
	str = str:gsub("/[/%*].-\n", "") -- really dont feel like coding comments
	local pos, tbl, curmap = 1, {}, {}
	curmap.tbl = tbl
	local curtbl = curmap.tbl
	local c pos, c = scanWhite(str, pos)
	repeat
		local token
		if c == "\"" then token, pos = scanString(str, pos)
		else token, pos = scanToken(str, pos) end
		pos, c = scanWhite(str, pos)
		if c == "{" then
			curtbl[token] = {}
			curmap = {parent = curtbl, parentMap = curmap, tbl = curtbl[token]}
			curtbl = curtbl[token]
			pos = pos + 1
		elseif c == "}" then
			curtbl = curmap.parent
			curmap = curmap.parentMap
			pos = pos + 1
		else
			local val val, pos = scanString(str, pos)
			curtbl[token] = val
		end
		pos, c = scanWhite(str, pos)
	until not pos
	return tbl
end

local insert = table.insert

local function getIter(tbl)
	local order = {}
	for i in pairs(tbl) do
		table.insert(order, i)
	end
	return setmetatable({table = tbl, order = order, index = 1}, {__call = function(self)
		local i = self.order[self.index]
		self.index = self.index + 1
		return i, self.table[i]
	end})
end

function kv.encode(tbl)
	local buffer, tab, iter = {}, "", getIter(tbl)
	local map = {iter = iter}
	local key, value = iter()
	repeat
		insert(buffer, tab) insert(buffer, "\"") insert(buffer, encodeString(tostring(key))) insert(buffer, "\"")
		if type(value) == "table" then
			insert(buffer, "\n") insert(buffer, tab) insert(buffer, "{\n")
			tab = tab .. "\t"
			iter = getIter(value)
			map = {parent = map, iter = iter}
		else
			insert(buffer, tab) insert(buffer, "\"") insert(buffer, encodeString(tostring(value))) insert(buffer, "\"\n")
		end
		repeat
			key, value = iter()
			if not key then
				tab = tab:sub(1, -2)
				map = map.parent
				if map then
					iter = map.iter
					insert(buffer, tab) insert(buffer, "}\n\n")
				end
			end
		until key or not map
	until not (key or map)
	return table.concat(buffer)
end

return kv