local discordia, tokens, gui = require('discordia'), require("./lua/token"), require("./lua/gui/autogui")

local client = discordia.Client()

local process_commands = false

local admin = {
	["^%s*start%s*"] = function( channel ) -- starts the event
		process_commands = true
	end,
	["^%s*stop%s*"] = function( channel ) -- stops the event
		process_commands = false
	end,
	["^%s*hide%s*"] = function( channel ) -- hides the channel
		
	end,
	["^%s*layout%s*"] = function( channel ) -- sets the plant layout
		
	end,
	["^%s*pause%s*"] = function( ) -- pauses commands
		process_commands = false
	end,
	["^%s*resume%s*"] = function( ) -- resume commands
		process_commands = true
	end
}

local commands = {
	["^%s*plant%s*"] = function( channel ) -- plants a plant at a certain grid point
		gui.press("b")
	end
}

client:on('messageCreate', function(message)
	if message.channel.id == "965126531624083498" and message.author.id ~= "941372431082348544" then
		if message.member:hasPermission(message.channel, 0x00000010) then
			for i,v in pairs(admin) do
				if message.channel:match(i) then v( message.channel ) end
			end
		end
		for i,v in pairs(commands) do
			if message.channel:match(i) and process_commands then v( message.channel ) end
		end
	end
end)

client:run('Bot ' .. tokens.getToken( 1 ))