local uv, timer, data = require("uv"), require("timer"), require("directory")

local processes, threads, paused = {}, {}, false

local lastwritten

-- start bots --

for i=2,#args do
	local outbuffer, errbuffer
	
	local cwd, file = args[i]:match("^(.-)[/\\]?([^/\\]+)$")
	cwd, file = cwd ~= "" and cwd or nil, file .. ".lua"
	
	threads[i-1] = coroutine.create(function()
		repeat
			local stdin, stdout, stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
			
			processes[i-1] = uv.spawn("luvit", {
				cwd = cwd,
				args = {file},
				stdio = {stdin, stdout, stderr}
			}, function()
				if not paused then
					timer.setTimeout(5000, function()
						if paused then return end
						assert(coroutine.resume(threads[i-1]))
					end)
				end
			end)
			
			if errbuffer then stdin:write(errbuffer) end
			outbuffer, errbuffer = {}, {}
			
			stdout:read_start(function(err, chunk)
				if not chunk then return end
				if lastwritten ~= i then table.insert(outbuffer, "\n") io.write("\n") end
				table.insert(outbuffer, chunk) io.write(chunk)
				lastwritten = i
			end)
			
			stderr:read_start(function(err, chunk)
				if not chunk then return end
				if lastwritten ~= i then table.insert(errbuffer, "\n") io.write("\n") end
				table.insert(errbuffer, chunk) io.write(chunk)
				lastwritten = i
			end)
			
			coroutine.yield()
		until false
	end)
	
	assert(coroutine.resume(threads[i-1]))
end

-- exit key --

local stdin = process.stdin.handle

stdin:set_mode(1) -- allows for input

local function killProcesses()
	for _,v in ipairs(processes) do
		v:kill()
	end
end

local keys = {}
local starttime = uv.gettimeofday()
keys.q = function()
	process.stdout:write("\x1b[?1049l")
	killProcesses()
	process.stdout:write("quitted, uptime: " .. tostring(uv.gettimeofday() - starttime) .. "s\n")
	stdin:set_mode(0)
	process:exit()
end
keys.r = function()
	process.stdout:write("\nrestarting\n\n")
	killProcesses()
end
keys.p = function()
	if paused then
		for _,v in ipairs(threads) do coroutine.resume(v) end
		paused = false
		process.stdout:write("\nresumed\n\n")
	else
		killProcesses()
		paused = true
		process.stdout:write("\npaused\n\n")
	end
end
keys.c = function()
	process.stdout:write("\x1b[2J\x1b[0;0H")
end

stdin:read_start(function(err, chunk)
	if err then return end
	
	local run = keys[chunk]
	if run then run() end
end)

-- setup alt buffer

process.stdout:write("\x1b[?1049h")