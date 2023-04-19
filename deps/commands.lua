local discordia = require("discordia")
local enums = discordia.enums
local class = discordia.class

local Client = class.classes.Client
local Container = class.classes.Container
local Command = class("Command", Container)

function Client:getCommand( id )
	
	return Command({id = id},self)
	
end

function Client:defaultCommandCallback( func )
	
	self._commandCallbacks["0"] = {func}
	
end

local oldinit = Client.__init

function Client:__init( ... )
	
	self._commandCallbacks = {}
	
	local returns = {oldinit(self, ...)}
	
	self:on("interactionCreate", function(interaction)
		if not (interaction.type == enums.interactionType.applicationCommandAutocomplete or interaction.type == enums.interactionType.applicationCommand) then return end
		local data = interaction.data
		
		local cmd, opt = self._commandCallbacks[data.id], data.options
		
		--interaction:reply("test1")
		
		while opt do
			if (not opt[1]) or opt[1].type > 2 then break end
			cmd, opt = cmd[opt[1].name], opt[1].options
			if not cmd then return end
		end
		
		local args, argsOrdered, focused = {}, {}
		
		for i,v in ipairs(opt) do
			if v.focused then focused = v end
			args[v.name] = v.value
			argsOrdered[i] = v.value
		end
		
		if interaction.type == enums.interactionType.applicationCommand then
			local callback = cmd[1]
			if not callback then return end
			
			callback(interaction, args, argsOrdered)
			
		else
			local callback = cmd[2]
			if not callback then return end
			
			interaction:autocomplete(callback(interaction, args, argsOrdered, focused))
			
		end
		
	end)
	
	return unpack(returns)
	
end

local function register( self, mode, path, func )

	local cbs = self.client._commandCallbacks
	cbs[self._id] = cbs[self._id] or {}
	cbs = cbs[self._id]
	
	for _,v in ipairs(path) do
		cbs[v] = cbs[v] or {}
		cbs = cbs[v]
	end
	
	cbs[mode] = func
	
end

function Command:used( path, func ) register(self, 1, path, func) end

function Command:autocomplete( path, func ) register(self, 2, path, func) end