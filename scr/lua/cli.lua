local uv = require("uv")
assert( uv.tty_get_vterm_state() == "supported", "not running in console" )

local char, concat = string.char, table.concat
local ESC, SP = char(0x1B), char(0x20)

local cli = {}

local stdin, stdout, stderr = uv.new_tty( 0, true ), uv.new_tty( 1, false ), uv.new_tty( 2, false )

-- INPUT --
cli.input = {}

-- detemines how the console recieves user input
local modes = {["normal"] = 0, ["raw"] = 1, ["io"] = 2}
local input_mode = 0
function cli.input.setMode( mode ) input_mode = modes[mode] uv.tty_set_mode(stdin, input_mode) end
function cli.input.resetMode() uv.tty_reset_mode() end

-- whether to send keycodes or the raw stdin data
local useKeycodes = true
function cli.input.useKeycodes( use ) useKeycodes = use end

-- whether to emit numbers or sequences for numpad
local keypad_modes = {application = "=", numeric = ">"}
function cli.input.setKeypadMode( self, mode ) stdout:write({ESC, keypad_modes[mode]}) end

-- how to emit arrow key sequences
local cursor_modes = {application = "h", normal = "l"}
function cli.input.setCursorMode( self, mode ) stdout:write({ESC, "[?1", cursor_modes[mode]}) end

-- input callback
local function parseCharacter( data, ignoreAlt )
	local c, alt = data:sub(1,1), false
	
	if c == ESC then
		local nextChar = data:sub(2,2)
		
		if nextChar == "" then
			c = ESC
		elseif (nextChar ~= "[") and (not ignoreAlt) then
			data = data:sub(2,-1)
			data, c = parseCharacter( data, true )
			alt = true
		else
			c = data:match(".[%[%d;]+.") or c
		end
	end
	data = data:sub(#c + 1, -1)
	
	return data, c, alt
end

local inputCallbacks = {}

function cli.input.removeCallback( callback )
	
	for i,v in ipairs(inputCallbacks) do
		if v == callback then table.remove( inputCallbacks, i ) break end
	end
	
end

function cli.input.addCallback( callback )
	
	cli.input.removeCallback( callback )
	table.insert( inputCallbacks, callback )
	
	return callback
	
end

-- call

stdin:read_start( function( err, data )
	if input_mode ~= 1 then for _,v in ipairs(inputCallbacks) do v( data ) end end
	local sequences = {}
		
	repeat
		local c, alt
		data, c, alt = parseCharacter( data )
			
		if useKeycodes then
			for key,code in pairs(keycodes) do
				if c == code then c = key break end
			end
		end
			
		for _,v in ipairs(inputCallbacks) do v( c, alt ) end
	until #data <= 0
end)

-- OUTPUT --

-- buffer --
local buffer = {}

local bufferTimer = uv.new_timer()

local function sendBuffer() uv.timer_stop(bufferTimer) stdout:write(buffer) end

function addToBuffer( ... )
	
	for i,v in pairs({...}) do
		table.insert(buffer, tostring(v or ""))
	end
	
	uv.timer_start(bufferTimer, 0, 1, sendBuffer)
	
end

function cli.getBuffer() return table.concat(buffer) end

-- cursor --
cli.cursor = {}

-- move cursor around
function cli.cursor.up( rows ) addToBuffer( ESC, "[", rows, "A" ) end
function cli.cursor.down( rows ) addToBuffer( ESC, "[", rows, "B" ) end
function cli.cursor.forward( columns ) addToBuffer( ESC, "[", columns, "C" ) end
function cli.cursor.backward( columns ) addToBuffer( ESC, "[", columns, "D" ) end

function cli.cursor.nextLine( lines ) addToBuffer( ESC, "[", lines, "E" ) end
function cli.cursor.prevLine( lines ) addToBuffer( ESC, "[", lines, "F" ) end

function cli.cursor.setX( x ) addToBuffer( ESC, "[", x, "G" ) end
function cli.cursor.setY( y ) addToBuffer( ESC, "[", y, "d" ) end

function cli.cursor.setPos( x, y ) addToBuffer( ESC, "[", y, ";", x, "H" ) end
function cli.cursor.setHVP( x, y ) addToBuffer( ESC, "[", y, ";", x, "f" ) end

-- cursor visibility
function cli.cursor.setBlinking( blinking ) addToBuffer( ESC, "[12", blinking and "h" or "l" ) end
function cli.cursor.setVisible( visible ) addToBuffer( ESC, "[25", blinking and "h" or "l" ) end

-- cursor shape
local cursor_shapes = {user = 0, block = 1, underline = 3, bar = 5}

function cli.cursor.setShape( shape, blinking )
	if shape == user then addToBuffer( ESC, "[0", SP, "q" ) end
	
	addToBuffer( ESC, "[", cursor_shapes[shape] + (blinking and 0 or 1), SP, "q" )
end

-- viewport --
function cli.scrollUp( rows ) addToBuffer( ESC, "[", rows, "S" ) end
cli.panDown = cli.scrollUp
function cli.scrollDown( rows ) addToBuffer( ESC, "[", rows, "T" ) end
cli.panUp = cli.scrollDown

-- editing --

-- writing
function cli.writeString( str ) addToBuffer( str ) end

-- clearing
function cli.clear() addToBuffer( ESC, "[2J" ) end
function cli.clearBeforeCursor() addToBuffer( ESC, "[1J" ) end
function cli.clearAfterCursor() addToBuffer( ESC, "[0J" ) end
function cli.clearLine() addToBuffer( ESC, "[2K" ) end
function cli.clearLineBeforeCursor() addToBuffer( ESC, "[1K" ) end
function cli.clearLineAfterCursor() addToBuffer( ESC, "[0K" ) end

-- color
local visualCharacterAttributes = {default = 0, bold = 1, noBold = 22, underline = 4, noUnderline = 24, negitive = 7, positive = 27, 
fgBlack = 30, fgRed = 31, fgGreen = 32, fgYellow = 33, fgBlue = 34, fgMagenta = 35, fgCyan = 36, fgWhite = 37, fgDefault = 39,
bgBlack = 40, bgRed = 41, bgGreen = 42, bgYellow = 43, bgBlue = 44, bgMagenta = 45, bgCyan = 46, bgWhite = 47, bgDefault = 49,
fgBrightBlack = 90, fgBrightRed = 91, fgBrightGreen = 92, fgBrightYellow = 93, fgBrightBlue = 94, fgBrightMagenta = 95, fgBrightCyan = 96, fgBrightWhite = 97,
bgBrightBlack = 100, bgBrightRed = 101, bgBrightGreen = 102, bgBrightYellow = 103, bgBrightBlue = 104, bgBrightMagenta = 105, bgBrightCyan = 106, bgBrightWhite = 107}

function cli.setGraphicsRendition( ... )
	local sequence = {...}

	for i,v in ipairs(sequence) do
		sequence[i] = assert(visualCharacterAttributes[v], "VCA does not exist")
	end

	addToBuffer( ESC, "[", table.concat( sequence, ";" ), "m" )

end

-- DEBUGGING --

cli.debug = {}

local dbgIn, dbgOut, dbgProc

-- create a new command instance to output to
function cli.debug.spawnConsole()
	assert(not dbgProc, "debug console already spawned")
	
	dbgIn, dbgOut = uv.new_pipe(), uv.new_pipe()
	
	dbgProc = uv.spawn( "cmd.exe", {stdio = {dbgIn, dbgOut}, args = {}} )
	
end

return cli