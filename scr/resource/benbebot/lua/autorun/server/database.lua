--[[ player database spesifications 

ULong - global deaths
ULong - global kills
ULong - global taunts
ULong - global props destroyed
ULong - total rounds
ULong - unused
FOR EACH {
	Byte - length of steamID
	String - steamID
	UShort - deaths
	UShort - kills
	UShort - taunts
	UShort - props destroyed
	UShort - rounds won
	UShort - rounds lost
}

]]

print("Benbebot database manager loaded")

if SERVER then
	
	local tallys = {
		deaths = 0,
		kills = 0,
		taunts = 0,
		props = 0,
		rounds = 0,
		players = {}
	}
	
	hook.Add("PostPlayerDeath", "add_death_to_database", function(p)
		tallys.deaths = tallys.deaths + 1
		local userID = p:SteamID()
		if not tallys.players[userID] then tallys.players[userID] = {} end
		tallys.players[userID].deaths = (tallys.players[userID].deaths or 0) + 1
	end)
	hook.Add("PlayerDeath", "add_frag_to_database", function(p, _, a)
		if a and a:IsPlayer() and p ~= a then
			tallys.kills = tallys.kills + 1
			local userID = a:SteamID()
			if not tallys.players[userID] then tallys.players[userID] = {} end
			tallys.players[userID].kills = (tallys.players[userID].kills or 0) + 1
		end
	end)
	hook.Add("PlayerStartTaunt", "add_taunt_to_database", function(p)
		tallys.taunts = tallys.taunts + 1
		local userID = p:SteamID()
		if not tallys.players[userID] then tallys.players[userID] = {} end
		tallys.players[userID].taunts = (tallys.players[userID].taunts or 0) + 1
	end)
	hook.Add("PropBreak", "add_prop_to_database", function(p)
		tallys.props = tallys.props + 1
		local userID = p:SteamID()
		if not tallys.players[userID] then tallys.players[userID] = {} end
		tallys.players[userID].props = (tallys.players[userID].props or 0) + 1
	end)
	
end