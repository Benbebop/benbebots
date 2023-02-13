local appdata, encoder, spawn = require("./appdata"), require("./encoder"), require("coro-spawn")

local characterSet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

local function newFile()
	local index = (tonumber(appdata.read("player_download/index")) or 0) + 1
	appdata.write("player_download/index", index)
	return appdata.directory() .. "player_download/" .. encoder.toBase(index, #characterSet)
end

local dl = {}

function dl.stream(url)
	local proc = spawn("bin/youtube-dl.exe", {})
end

function dl.download(url)
	local proc = spawn("bin/youtube-dl.exe", {})
end

function dl.get_srt(url, lang)
	lang = lang or "en"
	local output = newFile()
	local proc = spawn("bin/youtube-dl.exe", {
		stdio = {true, true, true},
		args = {
			"--write-sub", "--write-auto-sub", "--skip-download", 
			"--sub-lang", lang,
			"-o", output,
			url
	}})
	proc:waitExit()
	return output
end

function dl.run(url, args)
	local final_args = {}
	for i,v in pairs(args) do
		table.insert(final_args, "--" .. i .. " " .. v)
	end
	table.insert(final_args, url)
	local proc = spawn("bin/youtube-dl.exe", {arg = final_args})
	proc:waitExit()
end

return dl