local fs = require("fs")

local token = {}

function token.set(name, value) _G.TOKENS[name] = value end

function token.load(path)
	_G.TOKENS = _G.TOKENS or {}
	for n, t in fs.readFileSync(path):gmatch("([^%s]+)%s+([^\n\r]+)") do
		token.set(n, t)
	end
end

if fs.existsSync(".tokens") then token.load(".tokens") end

function token.get(name)
	return _G.TOKENS[name]
end

return token