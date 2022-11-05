-- benbebot value encoder v0.6

local function justify( s, l, c )
	while #s < l do s = c .. s end
	return s
end

local function todec( bin )
	return tonumber( bin, 2 )
end

local function tobin(x)
	if type(x) == str then x = tonumber(x) end
	ret=""
	while x~=1 and x~=0 do
		ret=tostring(x%2)..ret
		x=math.modf(x/2)
	end
	ret=tostring(x)..ret
	return ret
end

local e = {}

function e.decodetext(str)
	if #str == 0 then return "" end
	local low = string.byte(str:sub(1, 1))
	str = str:sub(2, -1)
	local endstr = ""
	for i in str:gmatch(".") do
		endstr = endstr .. string.char(string.byte(i) + low)
	end
	return endstr
end

function e.encodetext(str)
	local low = math.huge
	for i in str:gmatch(".") do
		local b = string.byte(i)
		if b < low then
			low = b
		end
	end
	local endstr = string.char(low)
	for i in str:gmatch(".") do
		endstr = endstr .. string.char(string.byte(i) - low)
	end
	return endstr
end

local characterSet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

function e.toBase(num, base)
	base = base or #characterSet

	local str = ""

	while num > 0 do
		local q = math.floor(num / base)
		local r = num % base

		str = str .. characterSet:sub(r + 1, r + 1)
		num = q
	end

	return str:reverse()
end

function e.encodeLargeNumber( str, length )
	
	
	
end

function e.decodeLargeNumber( str )
	
	
	
end

return e