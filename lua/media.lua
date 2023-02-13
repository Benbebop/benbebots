local appdata, spawn, encoder, uv = require("./appdata"), require("coro-spawn"), require("./encoder"), require("uv")

local function newIndex()
	local index = tonumber(appdata.read("media/index"))
	appdata.write("media/index", index + 1)
	return encoder.toBase(index)
end

local media = {}

appdata.init({{"media/"},{"media/index", "10000"}})

function media.overlayTextImage(input, text, args)
	table.insert(args, appdata.directory() .. "media/" .. newIndex() .. input:match("%..-$"))
	local stdin = uv.new_pipe(true)
	stdin:write(text)
	local proc = spawn("bin/convert.exe", {
		stdio = {stdin, true, true},
		args = args
	})
	proc:waitExit()
	return args[#args]
end

function media.contentAware(image, factor)
	
end

return media