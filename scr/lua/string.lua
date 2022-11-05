-- string extention

local s = {}

local truncates = {title = 256, desc = 4096, name = 256, value = 1024, text = 2048, author = 256}

function s.truncate( str, mode, suffix )
	local mode = truncates[mode] or 256
	if #(str or {}) >= mode then
		if suffix then
			str = str:sub(1, mode - 3) .. "..."
		else
			str = str:sub(1, mode / 2 - 3) .. "..." .. str:sub(#str - (mode / 2 - 3), -1)
		end
	end
	return str
end

return s