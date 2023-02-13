local NUL = string.char(0)

if SERVER then
	
	local function pseudoPack( file, str )
		
		file:WriteByte( #str )
		file:Write( str )
		
	end
	
	hook.Add("InitPostEntity", "begin_pipe", function()
		
		local ip = game.GetIPAddress()
		
		if ip == "loopback" then return end
		
		repeat ip = game.GetIPAddress() until ip ~= "0.0.0.0:port"
		
		local ip1,ip2,ip3,ip4,port = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+):(%d+)")
		
		local f = file.Open("pipe.dat", "ab", "DATA")
		f:WriteByte( 0 ) f:WriteByte( 1 )
		f:WriteByte( tonumber(ip1) ) f:WriteByte( tonumber(ip2) ) f:WriteByte( tonumber(ip3) ) f:WriteByte( tonumber(ip4) ) f:WriteUShort( tonumber(port) )
		f:Close()
		
	end)
	
	hook.Add("PlayerDeath", "pipe_frag", function(p, w, a)
		if a and a:IsPlayer() and w:IsWeapon() then
			local f = file.Open("pipe.dat", "ab", "DATA")
			f:WriteByte( 0 ) f:WriteByte( 3 )
			pseudoPack(f, p:GetName()) pseudoPack(f, i:GetPrintName()) pseudoPack(f, a:GetName())
			f:Close()
		end
	end)
	
	gameevent.Listen( "player_connect" )
	hook.Add("player_connect", "pipe_connect", function( player )
		if player.bot == 0 then
			local f = file.Open("pipe.dat", "ab", "DATA")
			f:WriteByte( 0 ) f:WriteByte( 2 )
			pseudoPack(f, player.name) pseudoPack(f, player.networkid) pseudoPack(f, player.address)
			f:Close()
		end
	end)
	
	gameevent.Listen( "player_disconnect" )
	hook.Add("player_disconnect", "pipe_disconnect", function( player )
		if player.bot == 0 then
			local f = file.Open("pipe.dat", "ab", "DATA")
			f:WriteByte( 0 ) f:WriteByte( 5 )
			pseudoPack(f, player.name) pseudoPack(f, player.networkid) pseudoPack(f, player.reason)
			f:Close()
		end
	end)
	
end