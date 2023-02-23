local fs, path = require("fs"), require("path")

local function createPath( p )
	return path.join(os.getenv("LOCALAPPDATA"), "\\benbebots\\", p)
end

local function createTempPath( p )
	return path.join(os.getenv("TEMP"), "\\benbebots\\", p)
end

local ad = {unpack(fs)}

function ad.open( path, ... ) return fs.open(createPath( path ), ...) end
function ad.openTemp( path, ... ) return fs.open(createTempPath( path ), ...) end
function ad.openSync( path, ... ) return fs.openSync(createPath( path ), ...) end
function ad.openTempSync( path, ... ) return fs.openSync(createTempPath( path ), ...) end

function ad.unlink( path, ... ) return fs.unlink(createPath( path ), ...) end
function ad.unlinkSync( path ) return fs.unlinkSync(createPath( path )) end
function ad.unlinkTemp( path, ... ) return fs.unlink(createTempPath( path ), ...) end
function ad.unlinkTempSync( path ) return fs.unlinkSync(createTempPath( path )) end

function ad.mkdir( path, ... ) return fs.mkdir(createPath( path ), ...) end
function ad.mkdirSync( path, ... ) return fs.mkdirSync(createPath( path ), ...) end
function ad.mkdirTemp( path, ... ) return fs.mkdir(createTempPath( path ), ...) end
function ad.mkdirTempSync( path, ... ) return fs.mkdirSync(createTempPath( path ), ...) end

function ad.rmdir( path, ... ) return fs.rmdir(createPath( path ), ...) end
function ad.rmdirSync( path, ... ) return fs.rmdirSync(createPath( path ), ...) end
function ad.rmdirTemp( path, ... ) return fs.rmdir(createTempPath( path ), ...) end
function ad.rmdirTempSync( path, ... ) return fs.rmdirSync(createTempPath( path ), ...) end

function ad.readdir( path, ... ) return fs.readdir(createPath( path ), ...) end
function ad.readdirSync( path, ... ) return fs.readdirSync(createPath( path ), ...) end
function ad.readdirTemp( path, ... ) return fs.readdir(createTempPath( path ), ...) end
function ad.readdirTempSync( path, ... ) return fs.readdirSync(createTempPath( path ), ...) end

function ad.scandir( path, ... ) return fs.scandir(createPath( path ), ...) end
function ad.scandirSync( path, ... ) return fs.scandirSync(createPath( path ), ...) end
function ad.scandirTemp( path, ... ) return fs.scandir(createTempPath( path ), ...) end
function ad.scandirTempSync( path, ... ) return fs.scandirSync(createTempPath( path ), ...) end

function ad.exists( path, ... ) return fs.exists(createPath( path ), ...) end
function ad.existsSync( path ) return fs.existsSync(createPath( path )) end
function ad.existsTemp( path, ... ) return fs.exists(createTempPath( path ), ...) end
function ad.existsTempSync( path ) return fs.existsSync(createTempPath( path )) end

function ad.readFile( path, ... ) return fs.readFile(createPath( path ), ...) end
function ad.readFileSync( path, ... ) return fs.readFileSync(createPath( path ), ...) end
function ad.readFileTemp( path, ... ) return fs.readFile(createTempPath( path ), ...) end
function ad.readFileTempSync( path, ... ) return fs.readFileSync(createTempPath( path ), ...) end

function ad.writeFile( path, ... ) return fs.writeFile(createPath( path ), ...) end
function ad.writeFileSync( path, ... ) return fs.writeFileSync(createPath( path ), ...) end
function ad.writeFileTemp( path, ... ) return fs.writeFile(createTempPath( path ), ...) end
function ad.writeFileTempSync( path, ... ) return fs.writeFileSync(createTempPath( path ), ...) end

function ad.appendFile( path, ... ) return fs.appendFile(createPath( path ), ...) end
function ad.appendFileSync( path, ... ) return fs.appendFileSync(createPath( path ), ...) end
function ad.appendFileTemp( path, ... ) return fs.appendFile(createTempPath( path ), ...) end
function ad.appendFileTempSync( path, ... ) return fs.appendFileSync(createTempPath( path ), ...) end

return ad