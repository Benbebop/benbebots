local discordia, tokens = require('discordia'), require("./lua/token")

local client = discordia.Client()

client:on('messageCreate', function(message)
	if message.channel.type == 1 then
		print(message.author.name .. ": " .. message.content)
	end
end)

client:run('Bot ' .. tokens.getToken( 16 ))