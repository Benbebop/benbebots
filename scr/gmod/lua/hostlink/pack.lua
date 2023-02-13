--[[
	pack syntax is the same though missing any that are impossible
	subpack is avalible with ()
	subpack lets you pack pack operations with a length preceding it, like `s`
	
	please facepunch just add string.pack i beg you omg would it be so nice
]]

local NUL = string.char( 0 )

local function readNumber( packStr, pos )
	local cursor = pos
	repeat cursor = cursor + 1 until not packStr:sub(cursor, cursor):match( "^%d$" )
	return packStr:sub(pos, cursor - 1), cursor - 1
end

local function decodePackStr( packStr )
	local cursor, operations = 0, {}
	
	repeat
		local o = packStr:sub( cursor, cursor ) cursor = cursor + 1
		if o == "B" then table.insert( operations, "Byte" )
		elseif o == "h" then table.insert( operations, "Short" )
		elseif o == "H" then table.insert( operations, "UShort" )
		elseif o == "l" then table.insert( operations, "Long" )
		elseif o == "L" then table.insert( operations, "ULong" )
		elseif o == "f" then table.insert( operations, "Float" )
		elseif o == "d" then table.insert( operations, "Double" )
		elseif o == "i" or o == "I" then
			local sign, len = o == "i" and "U" or ""
			len, cursor = readNumber( packStr, cursor )
			if len == "1" then
				table.insert( operations, "Byte" )
			elseif len == "2" then
				table.insert( operations, sign .. "Short" )
			elseif len == "3" then
				table.insert( operations, sign .. "Short+" )
			elseif len == "4" then
				table.insert( operations, sign .. "Long" )
			end
		elseif o == "c" then
			local len
			len, cursor = readNumber( packStr, cursor )
			table.insert(operations, "Con") table.insert(operations, tonumber(len))
		elseif o == "z" then
			table.insert(operations, "Zero")
		elseif o == "s" then
			local len
			len, cursor = readNumber( packStr, cursor )
			table.insert(operations, "String") table.insert(operations, tonumber(len))
		elseif o == "(" then
			local subPack
			subPack, cursor = decodePackStr( packStr:sub( cursor, -1 ) )
			subPack.len, cursor = readNumber( packStr, cursor )
			table.insert(operations, subPack)
		elseif o == ")" then break
		elseif o == " " then
		else
			error("invalid packStr (" .. o .. ")")
		end
	until not packStr:sub( cursor, cursor )
	
	return operations, cursor
end

PrintTable(decodePackStr( "LlI4I3(LLHh)2s2" ))
print("test")

local bin = {}

function bin.pack( f, packStr, ... )
	local input, i = {...}, 0
	local iter = ipairs( ({decodePackStr( packStr )})[1] )
	for _,v in iter do
		i = i + 1
		if v == "Short+" then
			f:WriteShort( input[i] )
			f:Skip(-1)
		elseif v == "UShort+" then
			f:WriteUShort( input[i] )
			f:Skip(-1)
		elseif v == "Con" then
			local _, len, str = iter(), input[i]
			while #str < len do str = str .. NUL end
			f:Write( input[i]:sub( str:sub(1,len) ) )
		elseif v == "Zero" then
			f:Write( input[i] ) f:Write( NUL )
		elseif v == "String" then
			local _, len = iter()
		else
			f["Write" .. v]( f, input[i] )
		end
	end
end

function bin.unpack( f, packStr )
	local iter = ipairs( decodePackStr( packStr ) )
	for _,v in iter do
		i = i + 1
		if v == "Short+" then
			
		elseif v == "UShort+" then
			
		elseif v == "Con" then
		
		elseif v == "Zero" then
			
		elseif v == "String" then
			
		else
			f["Write" .. v]( f, input[i] )
		end
	end
end

return bin