local apis = {"webster", "youtube"}

local localTracker = {}

local m = {}

function getTrackers()
	local trackFile = io.open("lua/api/tracker.dat", "r")
	local tracks = {trackFile:read("*a"):match("(%d+)%s(%d+)")}
	trackFile:close()
	return tracks
end

for i,v in ipairs(apis) do
	m[v] = function( increment )
		if increment then
			local tracks = getTrackers()
			tracks[i] = tonumber( tracks[i] ) + increment
			local trackFile = io.open("lua/api/tracker.dat", "w+")
			trackFile:write(table.concat(tracks, " "))
			trackFile:close()
		else
			return  tonumber( getTrackers()[i] )
		end
	end
end

function m.clear()
	local tracks = getTrackers()
	for i in ipairs(tracks) do
		tracks[i] = 0
	end
	local trackFile = io.open("lua/api/tracker.dat", "w+")
	trackFile:write(table.concat(tracks, " "))
	trackFile:close()
end

return m