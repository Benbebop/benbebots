local discordia = require("discordia") require("token")

local benbebot = discordia.Client()
local familyGuy = discordia.Client()

local readys, thread = 0, coroutine.running()
local function func() readys = readys + 1 coroutine.resume(thread) end

benbebot:run("Bot " .. TOKENS.benbebot) benbebot:onceSync("ready", func)
familyGuy:run("Bot " .. TOKENS.familyGuy) familyGuy:onceSync("ready", func)

repeat coroutine.yield() until readys >= 2

local function request(self, method, url, ...) return self._api:request(method, string.format("/applications/%s%s", self.user.id, url), ...) end

--[[for _,command in ipairs(request(familyGuy, "GET", "/commands")) do
	request(familyGuy, "DELETE", string.format("/commands/%s", command.id))
end

for guild in familyGuy.guilds:iter() do
	for _,command in ipairs(request(familyGuy, "GET", string.format("/guilds/%s/commands", guild.id))) do
		request(familyGuy, "DELETE", string.format("/guilds/%s/commands/%s", guild.id, command.id))
	end
end]]

-- GLOBAL COMMANDS --

assert(request(familyGuy, "PUT", "/commands", {
	
	{
		type = 2,
		name = "block family guy clips",
		id = "1112628264075280464"
	}
	
}))

-- GUILD COMMANDS --

assert(request(benbebot, "PUT", "/guilds/1068640496139915345/commands", {
	
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
	},
	
	{
		type = 1,
		name = "getfile",
		description = "get a data file from the server",
		id = "1100968409765777479",
		options = {
			{
				type = 3,
				name = "location",
				description = "where to search for files in",
				required = true,
				choices = {
					{name = "appdata", value = "appdata"},
					{name = "temp", value = "temp"},
					{name = "garrysmod", value = "garrysmod"}
				}
			},{
				type = 3,
				name = "path",
				description = "file path",
				required = true,
				autocomplete = true
			}
		}
	},
	
	{
		type = 1,
		name = "control",
		description = "control the bots",
		id = "1101705431769948180",
		options = {
			{
				type = 1,
				name = "pull",
				description = "update to latest version"
			},{
				type = 1,
				name = "version",
				description = "get version information about the bots",
			},{
				type = 1,
				name = "restart",
				description = "restart the bots",
			}
		}
	},
	
	{
		type = 1,
		name = "motd",
		description = "force a motd",
		id = "1103908487278379110",
		options = {
			{
				type = 1,
				name = "force",
				description = "force a motd"
			},{
				type = 1,
				name = "queue",
				description = "queue next motd",
				options = {
					{
						type = 3,
						name = "url",
						description = "url of the track",
						required = true
					}
				}
			},{
				type = 1,
				name = "check",
				description = "check if motd exists already",
				options = {
					{
						type = 3,
						name = "url",
						description = "url of the track",
						required = true
					},{
						type = 5,
						name = "search",
						description = "search motd channel as well"
					}
				}
			}
		}
	},
	
	{
		type = 1,
		name = "apbot",
		description = "control the ap bot",
		id = "1104076920498434078",
		options = {
			{
				type = 1,
				name = "login",
				description = "start and login the ap bot"
			},{
				type = 1,
				name = "logout",
				description = "stop the ap bot",
			}
		}
	},
	
	{
		type = 1,
		name = "getinvitelink",
		description = "generate an invite link to join the bot to a server",
		id = "1106752557956726855",
		options = {
			{
				type = 6,
				name = "bot",
				description = "bot to get an invite link for"
			}
		}
	},
	
	{
		type = 1,
		name = "event",
		description = "modify events",
		id = "1107064787294236803",
		options = {
			{
				type = 1,
				name = "master",
				description = "master message to be sent when an event happens that does not change per event",
				options = {
					{
						type = 3,
						name = "id",
						description = "event identifier",
						required = true,
						autocomplete = true
					},{
						type = 3,
						name = "message",
						description = "message to be added"
					}
				}
			},{
				type = 1,
				name = "message",
				description = "message to be sent when an event happens",
				options = {
					{
						type = 3,
						name = "id",
						description = "event identifier",
						required = true,
						autocomplete = true
					},{
						type = 3,
						name = "message",
						description = "message to be added"
					}
				}
			},{
				type = 1,
				name = "active",
				description = "whether an event actively sends messages",
				options = {
					{
						type = 3,
						name = "id",
						description = "event identifier",
						required = true,
						autocomplete = true
					},{
						type = 5,
						name = "active",
						description = "is active",
						required = true
					}
				}
			},{
				type = 1,
				name = "channel",
				description = "channel to send an event in",
				options = {
					{
						type = 3,
						name = "id",
						description = "event identifier",
						required = true,
						autocomplete = true
					},{
						type = 7,
						name = "channel",
						description = "channel to send in",
					},{
						type = 3,
						name = "channelid",
						description = "id of channel to send in",
					}
				}
			}
		}
	},
	
	{
		type = 1,
		name = "eventadmin",
		description = "modify events",
		id = "1110642726703218768",
		options = {
			{
				type = 1,
				name = "new",
				description = "create a new event listener",
				options = {
					{
						type = 3,
						name = "id",
						description = "event identifier",
						required = true
					},{
						type = 6,
						name = "owner",
						description = "owner of event",
						required = true
					},{
						type = 7,
						name = "channel",
						description = "default channel",
						required = true
					},{
						type = 3,
						name = "master",
						description = "initial master message"
					},{
						type = 3,
						name = "message",
						description = "initial message"
					},{
						type = 5,
						name = "active",
						description = "default active state"
					}
				}
			},{
				type = 1,
				name = "pubsubhubbub",
				description = "manage pubsubhubbub",
				options = {
					{
						type = 3,
						name = "id",
						description = "event identifier",
						required = true,
						autocomplete = true
					},{
						type = 3,
						name = "hub",
						description = "hub url",
						required = true
					},{
						type = 3,
						name = "topic",
						description = "topic url",
						required = true
					},{
						type = 5,
						name = "subscribe",
						description = "send a subscribe request or unsubscribe request"
					}
				}
			},{
				type = 1,
				name = "zapier",
				description = "manage zapier",
				options = {
					{
						type = 3,
						name = "id",
						description = "event identifier",
						required = true,
						autocomplete = true
					},{
						type = 3,
						name = "channel",
						description = "youtube id",
						required = true
					}
				}
			}
		}
	},
	
	{
		type = 1,
		name = "emojihash",
		description = "get emoji data",
		options = {
			{
				type = 3,
				name = "emoji",
				description = "emoji"
			}
		}
	},
	
}))

assert(request(familyGuy, "PUT", "/guilds/1068640496139915345/commands", {
	
	{
		type = 1,
		name = "clip",
		description = "manage family guy clips",
		id = "1112626905087225896",
		options = {
			{
				type = 1,
				name = "add",
				description = "add a clip",
				options = {
					{
						type = 11,
						name = "file",
						description = "file to add",
						required = true
					},{
						type = 4,
						name = "season",
						description = "source season that the clip originates from"
					},{
						type = 4,
						name = "episode",
						description = "source episode that the clip originates from"
					}
				}
			},{
				type = 1,
				name = "remove",
				description = "remove a clip",
				options = {
					{
						type = 3,
						name = "id",
						description = "id of clip to remove",
						required = true
					}
				}
			}
		}
	}
	
}))

benbebot:stop()
familyGuy:stop()

os.exit()