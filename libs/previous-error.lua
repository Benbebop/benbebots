local discordia, appdata = require("discordia"), require("appdata")

local pe = {}
pe.error_footer = {text = "Report this error at https://github.com/Benbebop/benbebots/issues."}

function pe.getError( name )
	local file = string.format("logs/err_%s.log", name)
	local err = appdata.readFileTempSync( file )
	if not err then return nil end
	appdata.unlinkTempSync( file )
	
	local errorName, traceback1, traceback2 = err:match("^%s*(.-)%s*stack%straceback:%s*(.-)%s*stack%straceback:%s*(.-)%s*$")
	
	return {embed = {
		description = string.format("%s\n%s", errorName, traceback1),
		footer = pe.error_footer,
		timestamp = discordia.Date():toISO('T', 'Z')
	}}
end

return pe