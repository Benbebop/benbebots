local file = args[2]

table.remove(args, 1)

local success, err = pcall(function() require("./" .. file) end)

if not success then
	print(err)
	io.read()
end