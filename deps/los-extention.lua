local uv = require("uv")

local los = require("los")

function los.isProduction()
	return uv.os_gethostname() == "benbebop-server"
end

return "test"
