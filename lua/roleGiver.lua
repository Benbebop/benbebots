local lwz, appdata = require("./lualwz"), require("./appdata")

local m = {}

function m.checkPatterns( roles, input )
	local id
	roles:forEach(function( role )
		if input:match("%s*" .. role.name:lower():gsub("%s", "%%s%*") .. "%s*") then
			id = role.id
		end
	end)
	return id
end

--[[
permarole.dat spesifacations

FOR EACH
	byte[x] - user id
	byte[1] - 30 end of user id
	uint32[4] - length of entry
	byte[x] - role id
	byte[1] - 30 end of role id
END

]]

local START, END, SEPERATOR, NULL = string.char(2), string.char(3), string.char(30), string.char(0)

local function readUntil(stream, character)
	local str, length = "", 0
	repeat
		local c = stream:read(1)
		length = length + 1
		if c and c ~= character then
			str = str .. c
		else
			break
		end
	until not c
	if str == "" then
		str = nil
	end
	return str, length
end

local function insert(offset, str, delete)
	local file = appdata.get("permaroles.dat", "r+") -- basically just io.open
	file:seek("set", offset + (delete or 0)) local post = file:read("*a") -- get stuff after insert
	file:seek("set", offset) file:write(str) file:write(post) -- write our stuff then put the before stuff back
	local newEnd, oldEnd = file:seek("cur"), file:seek("end") file:seek("set", newEnd)
	while file:seek("cur") <= oldEnd do
		file:write(NULL)
	end
	file:close()
end

local function findProfile(id)
	local file = appdata.get("permaroles.dat", "rb")
	local start, length, str, prefix, cur_id
	repeat
		cur_id, prefix = readUntil(file, SEPERATOR)
		if cur_id == id then
			length, start = string.unpack("I4", file:read(4)), file:seek("cur", -4)
			length = length + 2
			str = file:read(length)
			break
		elseif cur_id then
			file:seek("cur", string.unpack("I4", file:read(4)))
		end
	until not cur_id
	file:close()
	return start, length, str, prefix
end

function m.addPermarole(profile, role)
	role = (type(role) == "table") and role or {role}
	local start, length, content = findProfile(profile)
	if start then
		local role_data, success, count = content:sub(3,-1), false, 0
		for _,v in ipairs(role) do
			if not content:match(v .. SEPERATOR) then
				count = count + 1
				success = true
				role_data = role_data .. v .. SEPERATOR
			end
		end
		role_data = string.pack("I4", #role_data) .. role_data
		insert(start, role_data, length)
		return success, count
	else
		local role_data, count = "", 0
		for _,v in ipairs(role) do
			count = count + 1
			role_data = role_data .. v .. SEPERATOR
		end
		role_data = profile .. SEPERATOR .. string.pack("I4", #role_data) .. role_data
		local file = appdata.get("permaroles.dat", "a")
		file:write(role_data)
		file:close()
		return true, count
	end
end

function m.hasPermarole(profile, role)
	local _, _, content = findProfile(profile)
	if not _ then
		return nil
	elseif content:match(role or "0") then
		return true
	else
		return false
	end
end

function m.listPermaroles(profile)
	local _, _, content = findProfile(profile)
	if not _ then
		return nil
	else
		local tbl = {}
		for id in content:gmatch("(%d+)" .. SEPERATOR) do
			table.insert(tbl, id)
		end
		return tbl
	end
end

function m.getPermaroles()
	local file = appdata.get("permaroles.dat", "rb")
	local tbl = {}
	repeat
		local index = readUntil(file, SEPERATOR)
		if index then
			tbl[index] = true
			file:seek("cur", string.unpack("I4", file:read(4)))
		end
	until not l
	file:close()
	for i in pairs(tbl) do
		tbl[i] = m.listPermaroles(i)
	end
	return tbl
end

function m.deletePermarole(profile)
	local start, length, _, prefix = findProfile(profile)
	if start then
		p(start - prefix, length + prefix)
		insert(start - prefix, "", length + prefix)
	else
		return nil
	end
end

function m.removePermarole(profile, role)
	local start, length, content = findProfile(profile)
	if start then
		local content, changed = content:gsub(role .. SEPERATOR, "")
		if #content <= 0 then
			m.deletePermarole(profile)
		elseif changed >= 1 then
			insert(start, content, length)
			return true
		else
			return false
		end
	else
		return nil
	end
end

function m.parseCommand( message )
	if (message.channel.id == "822174811694170133") then
		return 0
	end
end

return m