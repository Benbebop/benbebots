function read( index )
	local lines = io.lines(".token")
	
	local token
	for i=1,index do
		token = lines()
	end
	return token
end

return read