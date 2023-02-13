local m = {}

function m.morethan( value, compare )
	value = tonumber(value) or 0
	compare = tonumber(compare) or 0
	if value > compare then
		return 1
	else
		return 0
	end
end

function m.morethaneql( value, compare )
	value = tonumber(value) or 0
	compare = tonumber(compare) or 0
	if value >= compare then
		return 1
	else
		return 0
	end
end
	
function m.lessthan( value, compare )
	value = tonumber(value) or 0
	compare = tonumber(compare) or 0
	if value < compare then
		return 1
	else
		return 0
	end
end

function m.lessthaneql( value, compare )
	value = tonumber(value) or 0
	compare = tonumber(compare) or 0
	if value <= compare then
		return 1
	else
		return 0
	end
end

function m.booltobin( bool )
	if bool then
		return 1
	else
		return 0
	end
end

return m