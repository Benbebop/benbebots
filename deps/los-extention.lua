local uv = require("uv")

local los = require("los")

function los.isProduction()
	return uv.os_gethostname() == "benbebot-server"
end

return "test"