local ffi = require("ffi")

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

return ll