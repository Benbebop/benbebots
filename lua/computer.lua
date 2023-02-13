local uv, p = require("uv"), {}

local m = {}

function m.getStatus()
	return require("discordia").package.version, _VERSION:lower()--, status or "nil", cpu or "nil", math.floor( memory * 100 ) / 100 or "nil", networkrecieve or "nil", networktransfer or "nil", networksignal or "nil", os.clock() - start
end

return m