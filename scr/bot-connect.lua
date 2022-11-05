local uv, spawn, discordia, timer, MicrophoneFFmpegProcess = require("uv"), require("coro-spawn"), require("discordia"), require("timer"), require("MicrophoneFFmpegProcess")

local client = discordia.Client()

local device, channel

do

local proc = spawn("bin\\ffmpeg.exe", {stdio = {nil, nil, true}, args = {"-list_devices", "true", "-f", "dshow", "-i", "dummy", "-hide_banner"}})

io.write("please input VoiceChannel id: \n\n")

channel = io.read():match("%d+") or "0"

proc:waitExit()

local devices, index = {}, 0

io.write("\nplease input audio device: \n\n")

for device in proc.stderr:read():gmatch("%[dshow%s*@%s*.-%]%s*\"([^\"]-)\"%s*%(audio%)") do --%s*%[dshow%s*@%s*.-%]%s*Alternative%s*name%s*\"(.-)\"
	index = index + 1
	devices[index] = device
	io.write(index, ": ", device, "\n")
end

io.write("\n")

device = devices[tonumber(io.read():match("%d+") or 1)]

end

local microphone = spawn("bin\\ffmpeg.exe", {stdio = {nil, true, true}, args = {"-f", "dshow", "-i", "audio=" .. device, "-f", "s16le", "-acodec", "pcm_s16le", "-"}})

function playFFmpeg(connection, path, duration)
    if not connection._ready then
      return nil, 'Connection is not ready'
    end

    local stream = MicrophoneFFmpegProcess(path, 48000, 2)

    local elapsed, reason = connection:_play(stream, duration)
    stream:close()
    return elapsed, reason
end

client:on("ready", function()
	local connection = client:getChannel(channel):join()
	playFFmpeg(connection, 'audio=' .. device)
	microphone.handle:kill(0)
end)

client:run('Bot ' .. require("./lua/token").getToken(tonumber(args[2]) or 1))