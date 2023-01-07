local uv = require("uv")

local srcds = {}



return function( dir, maxPlayers, gamemode, map, onExit )
	local self = {dir = dir}
	
	self.stdin, self.stdout, self.stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
	
	self.proc = uv.spawn(dir .. "/SrcdsConRedirect.exe", {stdio = {self.stdin, self.stdout, self.stderr}, args = {
		"+maxplayers", maxPlayers or 128,
		"+gamemode", gamemodeStr,
		"+map", workshopCollection[3] or "gm_construct",
		"+host_workshop_collection", workshopCollection[2],
		"-console", "-p2p"
	}}, function() end)
	
	
	
	return setmetatable( self, srcds )
end