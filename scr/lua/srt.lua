local function parseTimestamp(str)
	local h, m, s, ms = str:match("(%d+):(%d+):(%d+),(%d+)")
	h, m, s, ms = assert(tonumber(h), str), assert(tonumber(m), str), assert(tonumber(s), str), assert(tonumber(ms), str)
	return s + (ms / 1000) + (m * 60) + (h * 3600)
end

local srt = {}

local stamp_match = "\n(%d+)%s*\n%s*([%d:,]+).-([%d:,]+)%s*\n(.-)%s*\n%s*$"

function srt.parse(str)
	local tbl = {}
	for index, tstart, tend, content in str:gmatch(stamp_match) do
		tbl[tonumber(index)] = {start = parseTimestamp(tstart), ["end"] = parseTimestamp(tend), content = content}
	end
	return tbl
end

function srt.format(str)
	return str:gsub("</?i>", "%*"):gsub("</?%w>", "")
end

function srt.itterator(str)
	local file = io.open(str, "rb")
	return function()
		local s = ""
		local index, tstart, tend, content
		repeat
			local str = file:read("*l")
			if not str then
				file:close()
				return
			end
			s = s .. "\n" .. str
			index, tstart, tend, content = s:match(stamp_match)
		until index
		return tonumber(index), parseTimestamp(tstart), parseTimestamp(tend), content
	end
end

return srt