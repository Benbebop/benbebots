local s = {}

local ipconfig = io.popen("ipconfig")

s.ip = ipconfig:read("*a"):match("IPv4 Address[%s%.]+:%s+([%d%.]+)")
s.ipmasked = s.ip:gsub("%d+%.", "0%.")

local file = io.open("servers/terraria/serverconfig.txt")
local terraria = file:read("*a")
file:close()

s.terrariaport = terraria:match("\nport=(%d+)")
s.terrariapass = terraria:match("\npassword=(.-)\n")
s.terrariamotd = terraria:match("\nmotd=(.-)\n")

s.minecraftport = 25565

s.youtubeport = 8642
s.youtubeadport = 8646

s.gmodport = 8647

return s