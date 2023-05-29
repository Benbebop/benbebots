-- for writing data to proper directories

local fs, path = require("fs"), require("path")

local PATH, TEMPPATH, SECRETPATH

local opsys = require("los").type()
if opsys == "win32" then
	PATH = path.join(os.getenv( "LOCALAPPDATA" ), "/benbebots")
	TEMPPATH = path.join(os.getenv( "TEMP" ), "/benbebots")
	SECRETPATH = path.normalize(path.join(os.getenv( "LOCALAPPDATA" ), "/../../benbebot-secrets"))
elseif opsys == "linux" then
	PATH = path.join(os.getenv("HOME"), "/.benbebots")
	TEMPPATH = "/var/tmp/benbebots"
	SECRETPATH = path.join(os.getenv("HOME"), "/.benbebots-secrets")
elseif opsys == "OSX" then -- i dont use OSX and dont care so idk if this works
	PATH = "~/Library/Application Support/benbebots"
	TEMPPATH = "~/Library/Caches/benbebots"
	SECRETPATH = "~/Library/Application Support/benbebots-secrets"
else
	PATH = "data"
	TEMPPATH = "data/temp"
	SECRETPATH = "secret-data"
end

fs.mkdirSync(PATH) fs.mkdirSync(TEMPPATH) fs.mkdirSync(SECRETPATH)

local data = {}

function data.path(rel)
	return path.join(PATH, rel)
end

function data.tempPath(rel)
	return path.join(TEMPPATH, rel)
end

function data.secretPath(rel)
	return path.join(SECRETPATH, rel)
end

return data
