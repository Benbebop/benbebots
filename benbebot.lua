local discordia = require("discordia") require("discordia-interactions") require("discordia-commands")
local enums = discordia.enums

local client = discordia.Client()

do -- DOWNLOAD COMMAND --
	local download = client:newSlashCommand("download"):setDescription("download a video from a variety of sites")
	local option = download:addOption( enums.applicationCommandOptionType.string, "url" ):setDescription("url to the video you want to download")

	local ytdlp, urlParse, queryString = require("yt-dlp"), require("url").parse, require("querystring")

	download:callback( function( interaction, args )
		local session = ytdlp( nil, args.url or "" )
		
		local err = session:parseUrl()
		
		if err then interaction:reply( err, true ) return end
		
		local formats, err = session:listFormats()
		
		if not formats then interaction:reply( err, true ) return end
	end )

end

p(client:run("Bot " .. require("read-token")(1)))
