local e = {}

local NUL, US = string.char(0), string.char(31)

local generic_characters = "%s%w%d%.%[%]%(%)#=_;:-"

function e.parseUTS(str)
	local output = ""
	local index = {}
	for i in str:gmatch("[^" .. generic_characters.. "]+") do
		if not index[i] then
			index[i] = true
			output = output .. i .. US
		end
	end
	return output:gsub(US .. "$", "")
end

function e.random()
	local f
	repeat f = io.open("tables/emoji_final.index", "rb") until f
	f:seek("set", math.random(1, f:seek("end")))
	repeat until (f:read(1) or US) == US
	local output = ""
	repeat
		local b = f:read(1)
		output = output .. (b or NUL)
	until (b or US) == US
	return output:gsub(US, "")
end

function e.get( index )
	local f = io.open("tables/emoji_final.index", "rb")
	local i = 0
	while i < index do
		if f:read(1) == US then i = i + 1 end
	end
	local output = ""
	repeat
		local b = f:read(1)
		output = output .. (b or NUL)
	until (b or US) == US
	return output:gsub(US, "")
end

return e