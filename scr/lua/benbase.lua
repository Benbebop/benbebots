local uv, fs, discordia, appdata, str_ext = require("uv"), require("fs"), require("discordia"), require("./appdata"), require("./string")

local truncate = str_ext.truncate

local BASE = {}

local client, prefix, PARENT_ENV

-- MISC --

local outputModes = {null = {255, 255, 255}, info = {0, 0, 255}, err = {255, 0, 0}, mod = {255, 100, 0}, warn = {255, 255, 0}, http = {113, 113, 255}}

function BASE.output( str, mode, overwrite_trace )
	if not str then return end
	print( str )
	if mode == "silent" then return end
	str = truncate(str, "desc", true)
	mode = mode or "null"
	local foot = nil
	if mode == "err" then foot = {text = debug.traceback()} end
	if overwrite_trace then foot = {text = overwrite_trace} end
	foot = truncate(foot, "text", true)
	mode = outputModes[mode] or outputModes.null
	str = str:gsub("%d+%.%d+%.%d+%.%d+", "\\*\\*\\*.\\*\\*\\*.\\*\\*\\*.\\*\\*")
	local o = client:getChannel("959468256664621106") or client:getChannel("1036882309271523379")
	if not o then return end
	o:send({
		embed = {
			description = str,
			color = discordia.Color.fromRGB(mode[1], mode[2], mode[3]).value,
			footer = foot,
			timestamp = discordia.Date():toISO('T', 'Z')
		}
	})
end

function BASE.sendPrevError( append )
	local file = "errorhandle/error" .. (append or "") .. ".log"
	local f = appdata.get(file, "r")
	if f then
		local content = f:read("*a")
		if content == "" then return end
		local err, trace = content:match("^(.-)\nstack traceback:\n(.-)$")
		BASE.output( err, "err", trace )
		f:close()
		appdata.delete(file)
	end
end

function BASE.assertDir( dir )
	
	fs.mkdir( dir )
	
end

-- stole this from gmod :( --
function BASE.niceSize( size )

	size = tonumber( size )

	if ( size <= 0 ) then return "0"
	elseif ( size < 1e+3 ) then return size .. " Bytes"
	elseif ( size < 1e+6 ) then return math.floor( size / 1e+3 ) .. " KB"
	elseif ( size < 1e+9 ) then return math.floor( size / 1e+6 ) .. " MB"
	end

	return math.floor( size / 1e+9 ) .. " GB"

end

local function pluralizeString( str, quantity )
	return str .. ( ( quantity ~= 1 ) and "s" or "" )
end

-- this too --
function BASE.niceTime( seconds )

	if ( seconds == nil ) then return "a few seconds" end

	if ( seconds < 60 ) then
		local t = math.floor( seconds )
		return t .. pluralizeString( " second", t )
	end

	if ( seconds < 60 * 60 ) then
		local t = math.floor( seconds / 60 )
		return t .. pluralizeString( " minute", t )
	end

	if ( seconds < 60 * 60 * 24 ) then
		local t = math.floor( seconds / (60 * 60) )
		return t .. pluralizeString( " hour", t )
	end

	if ( seconds < 60 * 60 * 24 * 7 ) then
		local t = math.floor( seconds / ( 60 * 60 * 24 ) )
		return t .. pluralizeString( " day", t )
	end

	if ( seconds < 60 * 60 * 24 * 365 ) then
		local t = math.floor( seconds / ( 60 * 60 * 24 * 7 ) )
		return t .. pluralizeString( " week", t )
	end

	local t = math.floor( seconds / ( 60 * 60 * 24 * 365 ) )
	return t .. pluralizeString( " year", t )

end

local itterator = {}
itterator.__call = function( self )
	if self.i >= self.c then self.i = 0 end
	self.i = self.i + 1
	return string.rep(".", self.i)
end

function BASE.activeIndicator( maxDots )
	
	return setmetatable( {i = 0, c = maxDots}, itterator )
	
end

function BASE.resumeYielded( thread )
	
	if coroutine.status( thread ) == "suspended" then
		coroutine.resume( thread )
	end
	
end


-- DEBUG FUNCTIONS --
local function getBinaryVersion( executable, argOverwrite )
	
	local thread = coroutine.running()
				
	local out, vstr = uv.new_pipe(false), ""
				
	uv.spawn("bin/" .. executable .. ".exe", {stdio = {nil, out}, args = {argOverwrite or "--version"}}, function()
		
		coroutine.resume( thread, vstr )
		
	end)
				
	out:read_start(function(err, data)
		if data then
			vstr = vstr .. data
		end
	end)
				
	return coroutine.yield()
	
end

local funcs = {
	print = {
		permissions = function( message )
			if not message.guild then message:reply("error?NO_GUILD") return end
			
			local str = ""
			
			for _,v in ipairs(message.guild.me:getPermissions(message.channel):toArray()) do
				
				str = str .. "[" .. v .. "]"
				
			end
			
			message:reply( str )
			
		end, userCount = function( message )
			
			message:reply(#client.users)
			
		end, serverCount = function( message )
			
			message:reply(#client.guilds)
			
		end, var = setmetatable({__index = function( _, index ) return 
			function( message )
				message:reply( tostring(_G.benbebase.debugVars[index] or "error?VARIABLE_NON_EXISTANT[" .. index .. "]") )
			end
		end}, {}), version = {
			lua = function( message ) message:reply(_VERSION:lower()) end,
			luv = function( message ) message:reply("luv " .. uv.version_string()) end,
			discordia = function( message ) message:reply("discordia " .. discordia.package.version) end,
			pcmmixer = function( message ) message:reply("pcmmixer 0.4.2") end,
			ytdlp = function( message ) message:reply("yt-dlp " .. getBinaryVersion( "yt-dlp" )) end,
			ffmpeg = function( message ) message:reply(getBinaryVersion( "ffmpeg", "-version" ):match("^[^\n\r]+")) end
		}, uptime = function( message ) message:reply(tostring(uv.uptime())) end,
		virtualmemory = function( message ) message:reply(tostring(uv.get_free_memory() / 1e+9) .. "GB") end
	}, git = {
		update = function( message )
			if message.author.id == "459880024187600937" then
				
				local reply = message:reply("updating the bot...")
				
				uv.spawn("update.bat", {args = {}}, function()
					reply:setContent("finished, reloading... ")
					
					os.exit()
				end)
				
			else message:reply("what you doing trying to update the bot???") return end
		end, pull = function( message )
			if message.author.id == "459880024187600937" then
				
				local reply = message:reply("pulling the bot...")
				
				uv.spawn("update.bat", {args = {}}, function()
					reply:setContent("finished")
				end)
				
			else message:reply("what you doing trying to update the bot???") return end
		end
	}, restart = function(message)
		if message.author.id == "459880024187600937" then
			message:reply("restarting...")
		
			os.execute("shutdown -r")
		end
	end
}

local function parseCommand( message )
	
	if message.author.id ~= "459880024187600937" then return end
	
	if message.content:sub(1,#prefix + 1) == prefix .. ">" then
		
		local object = funcs
		
		for index in (":" .. message.content:sub(#prefix + 2,-1)):gmatch(":([^:%s]+)") do
			
			object = object[index]
			
			if not object then message:reply("error?NON_EXISTANT[" .. index:upper() .. "]") return end
			
		end
		
		if type(object) == "function" then
			
			object( message )
			
		else
			
			message:reply("error?NOT_ENDOFPATH")
			
		end
		
	end
	
end

function BASE.initialise( c, p )
	
	client, prefix = c, p
	
	client:on("messageCreate", parseCommand)
	
end

_G.benbebase = BASE

_G.benbebase.debugVars = {}

return true