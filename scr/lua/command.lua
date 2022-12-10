local discordia = require("discordia")

benbebase.debugVars.commandCount = 0

-- COMMAND OBJECT --
local commandObject = {}
commandObject.__index = commandObject

function commandObject.setHelp( self, syntaxString, descriptionString )
	
	self.parent[2][self.index].stx = syntaxString
	self.parent[2][self.index].desc = descriptionString
	
end

function commandObject.setPublic( self, bool )
	
	self.parent[2][self.index].show = not not bool
	
end

local function enablePerms( self, index, ... )
	
	if not self.parent[2][self.index][index] then self.parent[2][self.index][index] = discordia.Permissions() end
	
	for _,v in ipairs({ ... }) do
		
		self.parent[2][self.index][index]:enable( discordia.enums.permission[v] )
		
	end
	
end

function commandObject.userPermission( self, ... )
	
	enablePerms( self, "perms", ... )
	
end

function commandObject.requiredPermissions( self, ... )
	
	enablePerms( self, "requires", ... )
	
end

-- COMMAND INDEX --
local commandIndex = {}
commandIndex.__index = commandIndex

function commandIndex.setUnauthorizedMessage( self, msg )
	
	self[3] = msg
	
end

function commandIndex.new( self, name, callback )
	
	local index = #self[2] + 1
	
	self[2][index] = { 
		name = name:lower(),
		func = callback, 
		stx = nil, 
		desc = nil, 
		show = nil,
		perms = nil
	}
	
	benbebase.debugVars.commandCount = #self[2]
	
	return setmetatable( {index = index, parent = self}, commandObject )
	
end

local function findCommand( commands, name )
	
	for i,v in ipairs( commands ) do
		
		if v.name == name then
			
			return i
			
		end
		
	end
	
end

function commandIndex.get( self, name )

	local found = findCommand( self[2], name )
	
	return found and setmetatable( {index = found, parent = self}, commandObject )
	
end

function commandIndex._parse( self, str )
	
	local _, fin, name = str:lower():find( "^%s*" .. self[1] .. "%s*([^%s]+)" )
	
	if not name then return end
	
	local argstr = str:sub( fin + 1, -1 )
	
	--TODO: rewrite to accept quoted strings
	local arguments = {}
	
	for arg in argstr:gmatch("%s*([^%s]+)") do
		table.insert(arguments, arg)
	end
	
	return name, arguments, argstr
	
end

function commandIndex.run( self, message, me )
	
	local name, args, argstr = commandIndex._parse( self, message.content )
	if not name then return end
	
	local command = self[2][findCommand( self[2], name )]
	if not command then return end
	
	if command.requires and me and me.getPermissions then
		
		local perm, other = command.perms, me:getPermissions(message.channel)
		
		if perm:intersection(other) ~= perm then
			message:reply("This command cannot be executed because benbebot does not have the required permissions. (" .. table.concat( other:complement( perm ):toArray(), ", " ) .. ")")
			return
		end
		
	end
	if command.perms then
		
		local perm, other = command.perms, message.member:getPermissions(message.channel)
		
		if perm:intersection(other) ~= perm then
			if self[3] then
				
				message:reply(self[3])
				
			end
			return
		end
		
	end
	
	command.func( message, args, argstr )
	
end

function commandIndex.runString( self, str )
	
	local name, args, argStr = commandIndex._parse( self, str )
	
	if not name then return end
	
	self[2][findCommand( self[2], name )].func( nil, args, argStr )
	
end

function create( prefix )
	
	return setmetatable({prefix, {}}, commandIndex)
	
end

return create