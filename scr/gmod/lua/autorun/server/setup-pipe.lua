file.CreateDir( "pseudopipe" )
local init = file.Open( "pseudopipe/pipe_init.dat", "wb", "DATA" )

-- ADD ALL LOADED ADDONS --

init:Write( "ADNS" )
init:WriteULong( 0 )

for _,v in ipairs( engine.GetAddons() ) do
	init:WriteULong( v.wsid )
	local file = v.file or "unknown"
	init:WriteByte( #file ) init:Write( file )
end

local pos = init:Tell()
init:Seek( 4 )
init:WriteULong( pos )

init:Close()

-- OPEN PSTDIO --

file.Write( "pseudopipe/pipe_0.dat" ) file.Write( "pseudopipe/pipe_1.dat" ) file.Write( "pseudopipe/pipe_2.dat" )