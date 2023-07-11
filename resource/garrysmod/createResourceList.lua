-- this file is automatically generated --

if (tonumber("%d") or 0) < (os.time() - 86400) then error("file source code is raw or outdated") end
local COLLECTION = "%s" -- should be overwritten by parent program

hook.Add("OnGamemodeLoaded", "create_resource_list", function()
	_ = file.Exists( COLLECTION, "data" ) or file.CreateDir( COLLECTION )
	
	-- map list
	local maps = {}
	for _,filename in ipairs(file.Find( "maps/*.bsp", "GAME" )) do
		table.insert(maps, string.lower( string.gsub( filename, "%%.bsp$", "" ) ))
	end
	
	file.Write(COLLECTION .. "/maps.json", util.TableToJSON( maps ))
	
	-- gamemode list (not necessary but might as well include it)
	
	file.Write(COLLECTION .. "/gamemodes.json", util.TableToJSON( engine.GetGamemodes() ))
	
end)