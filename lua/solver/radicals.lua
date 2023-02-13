local b = require("./lua/solver/basic")

root = b.root
isWhole = b.isWhole

local r = {}

function r.simplify( index, radicand, coefficient )
	if coefficient then
		radicand = radicand * coefficient ^ index
	end
	
	if isWhole( root( index, radicand ) ) then return root( index, radicand ) end
	
	local i = 1
	
	repeat i = i + 1 until isWhole( root( index, radicand / i ) ) or radicand / i <= i
	
	return 
end

return r