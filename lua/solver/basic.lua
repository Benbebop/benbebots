local b = {}

function b.root( index, radicand )
	return radicand ^ (1/index)
end

function b.isWhole( number )
	return number % 1 == 0
end

return b