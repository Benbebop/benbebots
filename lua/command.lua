local enums = require('discordia').enums

local m = {}

function m.parse( str )
	if (str:lower():match("^bbb") or str:lower():match("^benbebot") or str:lower():match("^cbbe")) then
		return str:gsub("^bbb%s*", ""):gsub("^benbebot%s*", ""):gsub("^cbbe%s*", "")
	else
		return false
	end
end

local commands = {}

local id = 0

function m.new( command, callback, syntax, desc, hidden, perms )
	id = id + 1
	commands[command] = { 
		func = callback, 
		stx = syntax or "", 
		desc = desc or "nil", 
		show = not hidden,
		id = id,
		perms = perms or {}
	}
end

function sort(tbl)
	local tblmax = 0
	for i in pairs(tbl) do
		tblmax = math.max(tblmax, tonumber(i))
	end
	local final = {}
	for i=1,tblmax do
		if tbl[i] then
			table.insert(final, tbl[i])
		end
	end
	return final
end

function m.get( command )
	print(command)
	if not command then
		local final = {}
		for i,v in pairs(commands) do
			if v.show then
				if #v.desc > 50 then
					v.desc = v.desc:sub(50) .. "..."
				end
				final[v.id] = {
					name = i,
					stx = v.stx,
					desc = v.desc
				}
			end
		end
		return sort(final)
	else
		return commands[command:match("^[%a%_]+")], command:match("^[%a%_]+")
	end
end

function m.run( command, message )
	command = command:lower()
	local index, argstr = command:match("^[%a%_]+"), command:gsub("^[%a%_]+%s*", "")
	index = index:lower()
	if commands[index] and message.author.id ~= "941372431082348544" then
		local allowed = true
		if commands[index].perms then
			local memberperms = message.member:getPermissions(message.channel)
			for _,v in ipairs(commands[index].perms) do
				allowed = allowed and memberperms:has(enums.permission[v])
			end
		end
		if allowed then
			local arguments = {}
			for arg in argstr:gmatch("%s*([^%s]+)") do
				table.insert(arguments, arg)
			end
			return pcall(commands[index].func, message, arguments, argstr )
		else
			message.channel:send("you are not allowed to use this command")
		end
	end
end

function m.runNoParse( command, argstr )
	command = command:lower()
	if commands[command] then
		local arguments = {}
		for arg in argstr:gmatch("%s*([^%s]+)") do
			table.insert(arguments, arg)
		end
		return pcall(commands[command].func, arguments, argstr )
	end
end

return m