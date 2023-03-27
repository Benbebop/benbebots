local uv, timer, data = require("uv"), require("timer"), require("data")

local function getPath( mode, name, prox )
	return data.tempPath(string.format("/logs/%s_%s%s.log", mode, name, prox and ".prox" or ""))
end

local processes, threads, paused = {}, {}, false

local lastwritten

-- start bots --

for i=2,#args do
	threads[i-1] = coroutine.create(function()
		repeat
			local stdout, stderr = uv.new_pipe(), uv.new_pipe()
			local stdoutpath, stderrpath = getPath( "out", args[i], true ), getPath( "err", args[i], true )
			local stdoutfile, stderrfile = assert(uv.fs_open(stdoutpath, "a", 0666)), assert(uv.fs_open(stderrpath, "a", 0666))
			
			processes[i-1] = uv.spawn("luvit", {
				args = {args[i] .. ".lua"},
				stdio = {0, stdout, stderr}
			}, function()
				uv.fs_close(stdoutfile) uv.fs_close(stderrfile)
				uv.fs_rename(stdoutpath, getPath( "out", args[i] )) uv.fs_rename(stderrpath, getPath( "err", args[i] ))
				
				if not paused then
					timer.setTimeout(5000, function()
						if paused then return end
						assert(coroutine.resume(threads[i-1]))
					end)
				end
			end)
			
			stdout:read_start(function(err, chunk)
				if not chunk then return end
				if lastwritten ~= i then io.write("\n") end
				io.write(chunk)
				uv.fs_write(stdoutfile, chunk)
				lastwritten = i
			end)
			
			stderr:read_start(function(err, chunk)
				if not chunk then return end
				if lastwritten ~= i then io.write("\n") end
				io.write(chunk)
				uv.fs_write(stderrfile, chunk)
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
keys.q = function()
	process.stdout:write("\nquitting\n\n")
	killProcesses()
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

stdin:read_start(function(err, chunk)
	if err then return end
	
	local run = keys[chunk]
	if run then run() end
end)
