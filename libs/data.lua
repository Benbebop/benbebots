-- for writing data to proper directories

local fs, path = require("fs"), require("path")

local PATH, TEMPPATH

local opsys = require("los").type()
if opsys == "win32" then
	PATH = path.join(os.getenv( "LOCALAPPDATA" ), "/benbebots")
	TEMPPATH = path.join(os.getenv( "TEMP" ), "/benbebots")
elseif opsys == "Linux" then
	PATH = path.join(os.getenv( "HOME" ), "/.benbebots")
	TEMPPATH = path.join(os.getenv( "HOME" ), "/.benbebots")
elseif opsys == "OSX" then -- i dont use OSX and dont care so idk if this works
	PATH = "~/Library/Application Support/benbebots"
	TEMPPATH = "~/Library/Caches/benbebots"
else
	PATH = "data"
	TEMPPATH = "data/temp"
end

local data = {}

function data.path(rel)
	return path.join(PATH, rel)
end

function data.tempPath(rel)
	return path.join(TEMPPATH, rel)
end

return data