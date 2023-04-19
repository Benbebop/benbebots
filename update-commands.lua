local discordia = require("discordia") require("token")

local benbebot = discordia.Client()
local familyGuy = discordia.Client()

local readys, thread = 0, coroutine.running()
local function func() readys = readys + 1 coroutine.resume(thread) end

benbebot:run("Bot " .. TOKENS.benbebot) benbebot:onceSync("ready", func)
familyGuy:run("Bot " .. TOKENS.familyGuy) familyGuy:onceSync("ready", func)

repeat coroutine.yield() until readys >= 2

local function request(self, method, url, ...) return self._api:request(method, string.format("/applications/%s%s", self.user.id, url), ...) end

--[[for _,command in ipairs(request(benbebot, "GET", "/commands")) do
	request(benbebot, "DELETE", string.format("/commands/%s", command.id))
end

for guild in benbebot.guilds:iter() do
	for _,command in ipairs(request(benbebot, "GET", string.format("/guilds/%s/commands", guild.id))) do
		request(benbebot, "DELETE", string.format("/guilds/%s/commands/%s", guild.id, command.id))
	end
end]]

-- GLOBAL COMMANDS --

-- GUILD COMMANDS --

request(benbebot, "PUT", "/guilds/1068640496139915345/commands", {
	
	{
		type = 1,
		name = "addinvite",
		description = "add an invite",
		id = "1097727252168445952",
		options = {
			{
				type = 3,
				name = "invite",
				description = "invite url/code",
				required = true
			}
		}
	},
	
	{
		type = 1,
		name = "gmod",
		description = "modify the gmod server",
		id = "1097727252168445953",
		options = {
			{
				type = 1,
				name = "start",
				description = "start the gmod server",
				options = {
					{
						type = 3,
						name = "gamemode",
						description = "gamemode to start the server on"
					},{
						type = 3,
						name = "map",
						description = "map to start the server on"
					}
				}
			},{
				type = 1,
				name = "addon",
				description = "add a new addon to the server",
				options = {
					{
						type = 3,
						name = "gamemode",
						description = "gamemode to attach the addon to"
					},{
						type = 3,
						name = "url",
						description = "url / id of the addon"
					}
				}
			},{
				type = 1,
				name = "admin",
				description = "toggle steam account's admin perms on the server, only use this for your own account",
				options = {
					{
						type = 3,
						name = "url",
						description = "url / steamid of your steam account",
						required = true
					}
				}
			}
		}
	}
	
})

os.exit()