local ffi, bit32 = require("ffi"), require("bit")

local function extractBits(num, mask, disp)
	return bit32.rshift(bit32.band(num, mask), disp)
end

local ll = {}

if require("los").type() == "linux" then -- c api only works on linux for some reason
	
	ffi.cdef[[
unsigned long long strtoull(
   const char *strSource,
   char **endptr,
   int base
);
long long strtoll(
   const char *strSource,
   char **endptr,
   int base
);
]]
	
	function ll.strtoull(str, base)
		return ffi.C.strtoull(str, nil, base or 10)
	end
	
	function ll.strtoll(str, base)
		return ffi.C.strtoll(str, nil, base or 10)
	end
	
else
	
	function ll.strtoull(str, base)
		local number, mult = 0ULL, tonumber("10", base)
		for i = 1, #str do
			number = (number * mult) + tonumber(string.sub(str, i, i), base)
		end
		return number
	end
	
	function ll.strtoll(str, base)
		return ffi.C.strtoll(str, nil, base or 10)
	end
	
end

function ll.tostring(longlong)
	return tostring(longlong):sub(1, -4)
end

function ll.pack(num)
	return string.pack("LL", bit32.lshift(bit32.band(num, 0xFFFFFFFFULL), 32), bit32.band(num, 0x00000000FFFFFFFFULL))
end

function ll.unpack(str)
	local high, low = string.unpack("LL")
	return 
end

return ll