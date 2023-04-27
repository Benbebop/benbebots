local fs = require("fs")

local header = {"time"}
local tbl = {header}

local file = fs.openSync("1100874208256458912.dat")
local cursor = 0
local startTime
local prev = {}

local data = fs.readSync(file, 10, cursor) cursor = cursor + 10
repeat
	local add, seconds, mircoseconds, size = string.unpack("I1>I4>I4>I1>", data)
	
	local hash = fs.readSync(file, size, cursor) cursor = cursor + size
	
	startTime = startTime or seconds
	local timestamp = #tbl + 1--seconds - startTime
	
	local new = {unpack(prev)}
	new[1] = timestamp
	
	local index
	for i=2,#header do
		if header[i] == hash then index = i end
	end
	if not index then
		index = #header + 1
		header[index] = hash
	end
	
	if add >= 1 then
		new[index] = (new[index] or 0) + 1
	else
		new[index] = (new[index] or 0) - 1
	end
	
	if prev[1] == timestamp then
		tbl[#tbl] = new
	else
		tbl[#tbl + 1] = new
	end
	prev = new
	
	data = fs.readSync(file, 10, cursor) cursor = cursor + 10
until data == ""

local outBuffer = {}

for _,v in ipairs(tbl) do
	table.insert(outBuffer, table.concat(v, ", "))
	table.insert(outBuffer, "\n")
end

fs.writeFileSync("out.csv", outBuffer)