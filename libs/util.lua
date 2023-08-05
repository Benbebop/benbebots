local util = {}

util.nearHuge = math.abs(tonumber(string.format("%d", math.huge)))

function util.range(value, ceiling, floor)
	ceiling = ceiling or math.huge
	return math.max(math.min(value, ceiling), floor or -ceiling)
end

local function i(current)
	local div = current / 1000
	return div, math.floor(div) <= 0, math.floor(current * 100) / 100
end

function util.fileSizeString(bytes)
	local scale, right, str = i(bytes)
	if right then
		return str .. "b", str, "bytes"
	end
	
	scale, right, str = i(scale)
	if right then
		return str .. "kb", str, "kb"
	end
	
	scale, right, str = i(scale)
	if right then
		return str .. "mb", str, "mb"
	end
	
	scale, right, str = i(scale)
	if right then
		return str .. "gb", str, "gb"
	end
	
	scale, _, str = i(scale)
	return str .. "tb", str, "tb"
end

local types = {st = "<t:%d:t>", lt = "<t:%d:T>", sd = "<t:%d:d>", ld = "<t:%d:D>", sdt = "<t:%d:f>", ldt = "<t:%d:F>", r = "<t:%d:R>"}

function util.createTimestamp(tsType, tsTime)
	return (types[tsType] or "<t:%d>"):format(util.range(math.floor(tsTime), 2^56))
end

function util.indexTable(tbl, indexes)
	for _,v in ipairs(indexes) do
		if type(tbl) ~= "table" then return nil end
		tbl = tbl[v]
	end
	return tbl
end

function util.ninsert(tbl, value)
	tbl.n = (tbl.n or 0) + 1
	tbl[tbl.n] = value
end

return util
