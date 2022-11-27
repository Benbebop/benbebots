local uv, fs, timer, querystring, json, appdata = require("uv"), require("fs"), require("timer"), require("querystring"), require("json"), require("./appdata")

local gma, pseudopipe = require("./srcds/gma"), require("./srcds/pipe")

local stdin, stdout, stderr, file_event = uv.new_pipe(), uv.new_pipe(), uv.new_pipe(), uv.new_fs_event()
local pipe
local session, onExit, joinString
local addons

local gmodDirectory = ""

local function resetVariables()
	if pipe then pipe:close() end pipe = nil
	local pipeDir = gmodDirectory .. "garrysmod/data/pseudopipe/"
	fs.unlinkSync(pipeDir .. "pipe_0.dat") fs.unlinkSync(pipeDir .. "pipe_1.dat") fs.unlinkSync(pipeDir .. "pipe_2.dat") fs.unlinkSync(pipeDir .. "pipe_init.dat")
	appdata.delete( "gmod.sess" )
	pstdin, pstdout, pstderr, pstdinit, session, onExit, joinString, addons = nil
end

local srcds = {}

function srcds.setDirectory( dir ) gmodDirectory = dir end

function srcds.getJoinUrl()
	if not joinString then return false end
	return "steam://run/4000//" .. querystring.urlencode("+" .. joinString)
end

function srcds.killServer()
	if session then uv.kill(session) end
end

function srcds.shutdownServer()
	if not pipe then return false, "server pipe not established" end
	local success = pipe:sendSignalSync( "shutdown", "host requested shutdown" )
	if success == 1 then
		srcds.killServer()
		return true
	else
		return false
	end
end

function srcds.setMap( map )
	if not pipe then return false, "server pipe not established" end
	return pipe:sendSignalSync( "set_map", map )
end

function srcds.getMaps()
	local maps = {}
	for _,file in ipairs( addons ) do
		local addon = gma.new( file )
		for _,v in ipairs( addon:getMaps() ) do
			table.insert( maps, v )
		end
		addon:close()
	end
	return maps
end

local gamemodeIndex = json.parse(fs.readFileSync("lua/srcds/gamemodes.json"))

function srcds.getGamemodes()
	local gms = {}
	for _,v in pairs( gamemodeIndex ) do
		table.insert( gms, v[1] )
	end
	return gms
end

function srcds.runCommand( str )
	if not pipe then return false, "server pipe not established" end
	return pipe:sendSignalSync( "concommand", str )
end

local function checkresume( thread, pstdin, pstdout, pstderr, pstdinit )
	
	if joinString and pstdin and pstdout and pstderr and pstdinit then
		coroutine.resume( thread )
	end
	
end

local function readInit()
	
	local init = fs.openSync( pstdinit )
	
	local fin = string.unpack( "L", fs.readSync( init, 4, 4 ) )
	local cursor = 8
	
	local maps = {}
	
	while cursor < fin do
		local wsid = string.unpack( "L", fs.readSync( init, 4, cursor ) ) cursor = cursor + 4
		local len = string.unpack("B", fs.readSync( init, 1, cursor )) cursor = cursor + 1
		local file = fs.readSync(init, len, cursor) cursor = cursor + len
	end
	
	return maps
	
end

function srcds.launch( gamemode, exitCallback )
	
	if session then return false end
	
	local workshopCollection, gamemodeStr
	
	for index,gm in pairs(gamemodeIndex) do
		if gamemode:lower():match(gm[1]:lower()) then
			gamemodeStr, workshopCollection = index, gm
			break
		end
	end
	
	if not gamemodeStr then return false, "gamemode doesnt exist" end
	
	p(gamemodeStr)
	
	resetVariables()
	
	local thread, pstdin, pstdout, pstderr, pstdinit = coroutine.running()
	
	local proc = uv.spawn(gmodDirectory .. "SrcdsConRedirect.exe", {
		stdio = {stdin, stdout, stderr},
		args = {"+maxplayers", "20", "-console", "+gamemode", gamemodeStr, "+map", workshopCollection[3] or "gm_construct", "+host_workshop_collection", workshopCollection[2], "-p2p"}, 
		verbatim = true, detached = true--, cwd = gmodDirectory
	}, function( ... ) if onExit then onExit( ... ) end resetVariables() end)
	
	session = proc:get_pid()
	
	-- WAIT FOR P2P ID --
	
	local p2pMessage
	
	stdout:read_start( function(err, data)
		if err or not data then return end
		
		p2pMessage = data:match("`(connect.-)`")
		if p2pMessage then
			joinString = p2pMessage
			checkresume( thread, pstdin, pstdout, pstderr, pstdinit )
		end
	end )
	
	-- WAIT FOR PSEUDOPIPE --
	
	local pipeDir = gmodDirectory .. "garrysmod/data/pseudopipe/"
	
	file_event:start(pipeDir, {}, function(err, filename, events)
		if events.rename then
			p(filename, filename == "pipe_0.dat", filename == "pipe_1.dat", filename == "pipe_2.dat")
			if filename == "pipe_0.dat" then
				pstdin = pipeDir .. filename
			elseif filename == "pipe_1.dat" then
				pstdout = pipeDir .. filename
			elseif filename == "pipe_2.dat" then
				pstderr = pipeDir .. filename
			elseif filename == "pipe_init.dat" then
				pstdinit = pipeDir .. filename
			end
			checkresume( thread, pstdin, pstdout, pstderr, pstdinit )
		end
	end)
	
	-- YIELD UNTIL READY --
	
	function onExit() coroutine.resume( thread ) end
	
	coroutine.yield()
	
	stdout:read_stop() file_event:stop()
	
	if not (joinString and pstdin and pstdout and pstderr and pstdinit) then return end
	
	pipe = pseudopipe( pipeDir )
	
	-- EXTRACT PSTDINIT --
	
	addons = {}
	
	local init = fs.openSync( pstdinit )
	
	local fin = string.unpack( "L", fs.readSync( init, 4, 4 ) )
	local cursor = 8
	
	while cursor < fin do
		local wsid = string.unpack( "L", fs.readSync( init, 4, cursor ) ) cursor = cursor + 4
		local len = string.unpack("B", fs.readSync( init, 1, cursor )) cursor = cursor + 1
		local file = fs.readSync(init, len, cursor) cursor = cursor + len
		if file:find( "^%a:" ) then
			table.insert(addons, file)
		else
			table.insert(addons, gmodDirectory .. "garrysmod/" .. file)
		end
	end
	
	fs.closeSync( init )
	
	-- SAVE SESSION DATA --
	
	appdata.write( "gmod.sess", string.pack( "LI3zzz", uv.gettimeofday(), session, pstdin, pstdout, pstderr ) )
	
	-- FINISHED LOADING --
	
	onExit = function() coroutine.wrap(exitCallback)() end
	
	return true
	
end

-- LOAD EXISTING SESSION --



return srcds