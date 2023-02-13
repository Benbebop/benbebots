local discordia = require("discordia")

local client = discordia.Client()

client:run("Bot " .. require("read-token")(1))