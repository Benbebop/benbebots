local encoder = require("encoder")

local t = io.open("token", "rb")

local entries = {}

for v in encoder.decodetext(t:read("*a")):gmatch("(.-)\n") do
	table.insert(entries, {key = v:match("[^%s]+"), desc = v:match("//%s*(.+)$")})
end

t:close()

function save(tbl)
	local str = ""
	if #tbl ~= 0 then
		for _,v in ipairs(tbl) do
			str = str .. v.key .. ((v.desc and " //" .. v.desc .. "\n") or "\n")
		end
		str = encoder.encodetext(str)
	end
	t = io.open("token", "wb")
	t:write(str)
	t:close()
end

function rest()

	for i,v in ipairs(entries) do
		io.write(i, ": ", v.desc or "no description", "\n")
	end
	
	n = #entries + 1
	
	io.write(n, ": new entry\n")
	
	io.write("\nchoose entry\n\n")
	
	local option = tonumber(io.read())
	
	if option == n then
		table.insert(entries, {desc = io.read(), key = io.read()})
		save(entries)
	else
		io.write("\nkey: ", entries[option].key, "\n\n[e]dit or [r]emove?\n\n")
		
		local action = io.read()
		
		if action:match("e") then
			io.write("\nenter new key\n")
			entries[option].key = io.read()
			save(entries)
		elseif action:match("r") then
			entries[option] = nil
			save(entries)
		end
	end 

	os.execute("cls")

	rest()

end

rest()