local uv, fs, timer, path = require("uv"), require("fs"), require("timer"), require("path")

local function getPath( mode, name, prox )
	return path.join(os.getenv( "TEMP" ), string.format("\\benbebots\\logs\\%s_%s%s.log", mode, name, prox and ".prox" or ""))
end

local lastwritten

for i=2,#args do
	local thread
	
	thread = coroutine.create(function()
		repeat
			local stdout, stderr = uv.new_pipe(), uv.new_pipe()
			local stdoutpath, stderrpath = getPath( "out", args[i], true ), getPath( "err", args[i], true )
			local stdoutfile, stderrfile = assert(uv.fs_open(stdoutpath, "a", 0666)), assert(uv.fs_open(stderrpath, "a", 0666))
			
			uv.spawn("luvit", {
				args = {args[i] .. ".lua"},
				stdio = {0, stdout, stderr}
			}, function()
				uv.fs_close(stdoutfile) uv.fs_close(stderrfile)
				uv.fs_rename(stdoutpath, getPath( "out", args[i] )) uv.fs_rename(stderrpath, getPath( "err", args[i] ))
				
				timer.setTimeout(5000, function()
					assert(coroutine.resume(thread))
				end)
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
	
	assert(coroutine.resume(thread))
end
