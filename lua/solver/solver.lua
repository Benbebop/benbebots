local solver = {}

solver.radical = require("./lua/solver/radicals")

local varname = "[%aθ]"

function solver.autoexec( mode, str )
	local resp = {success = false, reason = "", answer = "", steps = {}}

	if mode == "solve" then
		
	elseif mode == "equate" then
		local left, right = str:match("%s*(.-)%s*=%s*(-.)%s*")
		local var = str:match(varname)
	end
end

return solver