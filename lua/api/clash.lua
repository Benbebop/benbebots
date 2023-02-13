local http, json, tracker, getToken, appdata, discordia = require("coro-http"), require("json"), require("./lua/api/tracker"), require("./lua/token").getToken, require("../appdata"), require("discordia")

local c = {}

function c.getClanInfo( tag )
	local resp = {status = "NOT SET", data = nil}
	
	local success, clan = http.request("GET", "https://api.clashofclans.com/v1/clans/" .. tag, {{"Authorization", "Bearer " .. getToken( 9 )}})
	
	clan = json.parse(clan)
	
	if not (success.code == 200 and clan.clanLevel) then resp.status = "ConnectionError (table clan)" return resp end
	
	local lvlValue = math.min( clan.clanLevel / 10, 1 ) * 255
	
	resp.status = "OK"
	resp.data = {
		r = 255 - lvlValue,
		g = lvlValue,
		b = 0,
		name = clan.name,
		tag = clan.tag,
		trophies = clan.requiredTrophies,
		townhallLevel = clan.requiredTownhallLevel,
		wins = clan.warWins,
		ties = clan.warTies,
		losses = clan.warLosses,
		members = clan.members,
		image = clan.badgeUrls.small
	}
	
	return resp
end

function c.getWarInfo( tag )
	local resp = {status = "NOT SET", data = nil}
	
	local success, war = http.request("GET", "https://api.clashofclans.com/v1/clans/" .. tag .. "/currentwar", {{"Authorization", "Bearer " .. getToken( 9 )}})
	
	war = json.parse(war)
	
	if not (success.code == 200 and war.clan) then resp.status = "ConnectionError (table war)" return resp end
	
	resp.status = "OK"
	
	local destC = war.clan.destructionPercentage / 100 * 255
	if war.state == "inWar" then
		resp.data = {
			r = 255 - destC,
			g = destC,
			b = 0,
			c = war.clan.name,
			cTag = war.clan.tag,
			cDest = war.clan.destructionPercentage,
			cAttacks = war.clan.attacks,
			cStars = war.clan.stars,
			o = war.opponent.name,
			oTag = war.opponent.tag,
			oDest = war.opponent.destructionPercentage,
			oAttacks = war.opponent.attacks,
			oStars = war.opponent.stars,
			stamp = war.startTime
		}
	else
		resp.data = false
	end
	
	return resp
end

function c.getWarAnnounce( tag, role, arg )
	if arg ~= "war_announce" then arg = arg:match("^%s*(.+)%s*$") else arg = nil end
	
	local resp = {status = "NOT SET", data = nil}
	
	local success, war = http.request("GET", "https://api.clashofclans.com/v1/clans/" .. tag .. "/currentwar", {{"Authorization", "Bearer " .. getToken( 9 )}})
	
	war = json.parse(war)
	
	if success.code ~= 200 then resp.status = "ConnectionError (table war)" return resp end
	
	if war.state ~= "inWar" then resp.status = "OK" return resp end
	
	local success, opponent = http.request("GET", "https://api.clashofclans.com/v1/clans/" .. war.opponent.tag:gsub("#", "%%23"), {{"Authorization", "Bearer " .. getToken( 9 )}})
	
	opponent = json.parse(opponent)
	
	if success.code ~= 200 then resp.status = "ConnectionError (table opponent)" return resp end
	
	resp.status = "OK"
	resp.data = {
		content = role.mentionString,
		color = role.color,
		c = war.clan.name,
		cTag = war.clan.tag,
		desc = arg,
		o = war.opponent.name,
		oTag = war.opponent.tag,
		oWins = opponent.warWins,
		oTies = opponent.warTies,
		oLosses = opponent.warLosses,
		oMembers = opponent.members,
		stamp = war.startTime
	}
	
	return resp
end

c.liveEmbedInit = {
	description = "loading please wait"
}

local statusObj = {}
statusObj.__index = statusObj

function c.liveWarMessage( message, tag )
	
	local info = c.getWarInfo( tag )
	if info.status ~= "OK" then return info end
	
	return {status = "OK", data = setmetatable( {message = message, tag = tag, data = info.data, removed = false}, statusObj )}
	
end

function statusObj:setClan( tag )
	if self.removed then return end
	self.tag = tag
end

local function embed( data )
	if data then
		local destructionRatio = tonumber( data.cDest ) / tonumber( data.oDest ) / 2
		local starRatio = tonumber( data.cStars ) / tonumber( data.oStars ) / 10
		local totalRatio = (destructionRatio + starRatio) / 2
		return {
			title = data.c .. " VS " .. data.o,
			fields = {
				{name = data.c, value = data.cTag, inline = false},
				{name = "Destruction", value = data.cDest .. "%", inline = true},
				{name = "Attacks", value = data.cAttacks, inline = true},
				{name = "Stars", value = data.cStars, inline = true},
				{name = data.o, value = data.oTag, inline = false},
				{name = "Destruction", value = data.oDest .. "%", inline = true},
				{name = "Attacks", value = data.oAttacks, inline = true},
				{name = "Stars", value = data.oStars, inline = true},
			},
			-- description = "",
			-- image = {
				-- url = data.opponent.badgeUrls.small,
				-- height = 20,
				-- width = 20
			-- },
			color = discordia.Color.fromRGB(255 * math.max(1 - totalRatio, 0), 255 * math.min(totalRatio, 1), 0).value, --{data.r, data.g, data.b},
			timestamp = data.stamp
		}
	else
		return {
			description = "this war has ended"
		}
	end
end

function statusObj:update()
	if self.removed then return end
	local info = c.getWarInfo( self.tag )
	if info.status ~= "OK" or info.data == false then return info end
	self.data = info.data
	self.message:setEmbed( embed( self.data ) )
	return info
end

function statusObj:getMessage()
	if self.removed then return end
	return embed( self.data )
end

function statusObj:getData()
	if self.removed then return end
	return self.data
end

function statusObj:inWar()
	if self.removed then return end
	return self.data ~= false
end

function statusObj:delete()
	if self.removed then return end
	self.removed = true
	self.message:delete()
end

return c