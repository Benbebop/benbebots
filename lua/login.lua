--[[
.login spesifacations

byte[4] - URNM
uint32[4] - length of USERNAME section
FOR EACH
	uint8[1] - length of username
	byte[x] - username
	uint32[4] - distance from HASH section
END
byte[4] - HASH
FOR EACH
	byte[x] - user id
	byte[1] - 30 end of user id
	uint32[4] - length of entry
	byte[x] - role id
	byte[1] - 30 end of role id
END

]]

local l = {}

return l