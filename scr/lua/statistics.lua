local appdata, fs = require("./appdata"), require("fs")

appdata.init({{"statistics.db"}})

_G.statisticsOverlapDebug = ""

local stat = {}
stat.__index = stat

function stat.set( self, ... )
	local fd = appdata.getFd( "statistics.db", "r+" )
	fs.writeSync( fd, self.offset, string.pack( self.packStr, ... ) )
	fs.closeSync( fd )
end

function stat.increase( self, ... )
	local fd = appdata.getFd( "statistics.db", "r+" )
	local content = fs.readSync( fd, self.size, self.offset )
	if content ~= "" then 
		content = {string.unpack( self.packStr, content )}
		for i,v in ipairs({...}) do
			content[i] = content[i] + v
		end
		fs.writeSync( fd, self.offset, string.pack( self.packStr, unpack(content) ) )
		fs.closeSync( fd )
	else
		fs.closeSync( fd )
		stat.set( self, ... )
	end
end

function stat.get( self )
	local fd = appdata.getFd( "statistics.db", "r" )
	local content = {string.unpack( self.packStr, fs.readSync( fd, self.size, self.offset ) )}
	fs.closeSync( fd )
	return unpack( content )
end

return function( offset, size, packStr )
	
	-- detect overlap
	do
		local len = offset + size
		while #_G.statisticsOverlapDebug < len do _G.statisticsOverlapDebug = _G.statisticsOverlapDebug .. "0" end
		local part = _G.statisticsOverlapDebug:sub( offset, offset + size )
		for i=offset,offset + size do
			if part:sub(i,i) == "1" then
				_G.statisticsOverlapDebug = _G.statisticsOverlapDebug:sub( 1, i - 1 ) .. "2" .. _G.statisticsOverlapDebug:sub( i + 1, -1 )
				p(_G.statisticsOverlapDebug)
				error( "statistic part (" .. packStr .. ", " .. offset .. ") intercepts already existing part" )
			end
		end
		_G.statisticsOverlapDebug = _G.statisticsOverlapDebug:sub( 1, offset ) .. string.rep( "1", size ) .. _G.statisticsOverlapDebug:sub( offset + size + 1, -1 )
	end
	
	return setmetatable( {offset = offset, size = size, packStr = packStr}, stat )
	
end