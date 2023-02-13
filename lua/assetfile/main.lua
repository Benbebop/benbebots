local fs = require("fs")

local output = io.open((args[3] or "assetfile") .. ".ast", "wb")

output:write("ASTF")

function func(dir)
	local locations = {}
	for f,t in fs.scandirSync(dir) do
		if t == "directory" then
			output:write(string.pack("z", f))
			locations[f] = output:seek("cur")
			output:write(string.pack("LH", 0, 0))
		elseif f:sub(-4, -1) == ".vtf" or f:sub(-4, -1) == ".mdl" then
			output:write(string.pack("z", f))
		end
	end
	for f,t in fs.scandirSync(dir) do
		if t == "directory" then
			local ret1 = output:seek("cur")
			func(dir .. "/" .. f)
			local ret2 = output:seek("cur")
			output:seek("set", locations[f])
			output:write(string.pack("LH", ret1, ret2 - ret1))
			output:seek("set", ret)
		end
	end
end

func(args[2])