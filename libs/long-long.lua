local ffi = require("ffi")

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

local ll = {}

function ll.strtoull(str, base)
	return ffi.C.strtoull(str, nil, base or 10)
end

function ll.strtoll(str, base)
	return ffi.C.strtoll(str, nil, base or 10)
end

function ll.lltostr(ull)
	return tostring(ull):sub(1, -4)
end

return ll