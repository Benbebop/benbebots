local Matrix = {}
Matrix.__index = Matrix

function Matrix.Create( arraySize )
	matrix = {}
	
	setmetatable( matrix, Matrix )

	matrix.arraySize = arraySize

	for i = 1, arraySize, 1 do
		matrix[i] = 0
	end

	return matrix 
end

function Matrix:Clear()
	for i = 1, self.arraySize, 1 do
		self[i] = 0
	end
end

-- The Sudoku class stores the matrix array and implements the game logic.
-- Instantiation of this class will automatically generate a new puzzle.

local Sudoku = {}
Sudoku.__index = Sudoku

function Sudoku.Create( matrix )


	sudoku = {}
	
	setmetatable( sudoku, Sudoku )
	
	-- stores the 9x9 game data. the puzzle data is stored with revealed
	-- numbers as 1-9 and hidden numbers for the user to discover as zeros.
	sudoku.matrix = Matrix.Create( 81 )
	sudoku.mask = Matrix.Create( 81 )
	
	-- initial puzzle is all zeros.
	sudoku.matrix:Clear()

	-- stores the difficulty level of the puzzle 0 is easiest.
	sudoku.level = 0
	
	-- Randomise the seed 
	
	return sudoku 
end

--[[self method initializes the sudoku puzzle beginning with a root
	solution and randomly shuffling rows, columns and values. the result
	of self method will be a completely solved sudoku board. the shuffle
	is similar to that used by the sudoku puzzle at:
	
	http:--www.dhtmlgoodies.com/scripts/game_sudoku/game_sudoku.html


	self method takes one parameter:
	matrix - the 9x9 array to store the puzzle data. the array	
	contents will be overwritten by self method.]]
function Sudoku:shuffle( matrix ) 
		local dokuline = ""
		local tmp
		
	-- create the root sudoku solution. this produces the following
	-- sudoku:
	--
	-- 1 2 3 | 4 5 6 | 7 8 9
	-- 4 5 6 | 7 8 9 | 1 2 3
	-- 7 8 9 | 1 2 3 | 4 5 6
	-- ---------------------
	-- 2 3 4 | 5 6 7 | 8 9 1
	-- 5 6 7 | 8 9 1 | 2 3 4
	-- 8 9 1 | 2 3 4 | 5 6 7
	-- ---------------------
	-- 3 4 5 | 6 7 8 | 9 1 2
	-- 6 7 8 | 9 1 2 | 3 4 5
	-- 9 1 2 | 3 4 5 | 6 7 8
	for i = 0, 8, 1 do		
		for j = 1, 9, 1 do
			self.matrix[i * 9 + j] = (i * 3 + math.floor( i / 3 ) + ( j - 1) ) % 9 + 1
		end
	end
				
	-- randomly shuffle the numbers in the root sudoku. pick two
	-- numbers n1 and n2 at random. scan the board and for each
	-- occurence of n1, replace it with n2 and vice-versa. repeat
	-- several times. we pick 42 to make Douglas Adams happy.
	for i = 1, 42, 1 do
		local n1 = math.random( 9 )
		local n2
		
		repeat
			n2 = math.random( 9 )

		until n1 ~= n2

		for row = 0, 8, 1 do
			for col = 1, 9, 1 do
				if self.matrix[row * 9 + col] == n1 then
					self.matrix[row * 9 + col] = n2
				elseif(self.matrix[row * 9 + col] == n2) then
					self.matrix[row * 9 + col] = n1
				end
			end
		end
	end
	
--[[print( "\n" )
	
	-- Test output by printing it to the console
	for i = 0, 8, 1 do
		for j = 1, 9, 1 do
			dokuline = dokuline .. tostring( self.matrix[ i * 9 +  j ]) .. ','
		end
		dokuline = dokuline .. " Row " .. i .. '\n'
		print( dokuline )
	end]]	

	-- randomly swap corresponding columns from each column of
	-- subsquares
	--
	--   |       |       |
	--   |       |       |
	--   V       V       V
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	------------------------
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	------------------------
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	--
	-- note that we cannot swap corresponding rows from each row of
	-- subsquares.
	for c = 1, 42, 1 do 
		local s1 = math.random( 2 )
		local s2 = math.random( 2 ) 

		for row = 0, 8, 1 do
			tmp = self.matrix[row * 9 + (s1 * 3 + c % 3)]
			self.matrix[row * 9 + (s1 * 3 + c % 3)] = self.matrix[row * 9 + (s2 * 3 + c % 3)]
			self.matrix[row * 9 + (s2 * 3 + c % 3)] = tmp
			
			--print( "Row is " .. row .. "tempt is " ..  tostring(tmp) .. " C is " .. c .. " S1 is " .. s1 .. " S2 is " .. s2  )
			--print( "Row " .. row .. " Position1 is " .. row * 9 + (s1 * 3 + c % 3) .. " Position2 is " .. row * 9 + (s2 * 3 + c % 3) )
		end
	end

--[[print( "\n" )
	
	-- Test output by printing it to the console
	for i = 0, 8, 1 do
		for j = 1, 9, 1 do
			dokuline = dokuline .. tostring( self.matrix[ i * 9 +  j ]) .. ','
		end
		dokuline = dokuline .. " Row " .. i .. '\n'
		print( dokuline )
	end]]

	-- randomly swap columns within each column of subsquares
	--
	--         | | |
	--         | | |
	--         V V V
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	------------------------
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	------------------------
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	for s = 1, 42, 1 do
		local c1 = math.random( 2 )
		local c2 = math.random( 2 )

		for row = 0, 8, 1 do
			local tmp = self.matrix[row * 9 + (s % 3 * 3 + c1)]
			self.matrix[row * 9 + (s % 3 * 3 + c1)] = self.matrix[row * 9 + (s % 3 * 3 + c2)]
			self.matrix[row * 9 + (s % 3 * 3 + c2)] = tmp
		end
	end

--[[print( "\n" )
	
	-- Test output by printing it to the console
	for i = 0, 8, 1 do
		for j = 1, 9, 1 do
			dokuline = dokuline .. tostring( self.matrix[ i * 9 +  j ]) .. ','
		end
		dokuline = dokuline .. " Row " .. i .. '\n'
		print( dokuline )
	end]]

	-- randomly swap rows within each row of subsquares
	--
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	------------------------
	-- . . . | . . . | . . . <---
	-- . . . | . . . | . . . <---
	-- . . . | . . . | . . . <---
	------------------------
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	-- . . . | . . . | . . .
	for s = 1, 42, 1 do
		local r1 = math.random( 2 ) 
		local r2 = math.random( 2 )

		for col = 1, 9, 1 do
			local tmp = self.matrix[(s % 3 * 3 + r1) * 9 + col]
			self.matrix[(s % 3 * 3 + r1) * 9 + col] = self.matrix[(s % 3 * 3 + r2) * 9 + col]
			self.matrix[(s % 3 * 3 + r2) * 9 + col] = tmp
		end
	end
	
	print( "\n" )

	-- Test output by printing it to the console
	for i = 0, 8, 1 do
		for j = 1, 9, 1 do
			dokuline = dokuline .. tostring( self.matrix[ i * 9 +  j ]) .. ','
		end
		dokuline = dokuline .. " Row " .. i .. '\n'
	end
	
	print( dokuline )

	-- we could also randomly swap rows and columns of subsquares
	--
	--   |       |       |
	--   |       |       |
	-- /---\   /---\   /---\
	-- . . . | . . . | . . .  \
	-- . . . | . . . | . . .  | <---
	-- . . . | . . . | . . .  /
	------------------------
	-- . . . | . . . | . . .  \
	-- . . . | . . . | . . .  | <---
	-- . . . | . . . | . . .  /
	------------------------
	-- . . . | . . . | . . .  \
	-- . . . | . . . | . . .  | <---
	-- . . . | . . . | . . .  /
	--
	-- we could also rotate the board 90, 180 or 270 degrees and
	-- mirror left to right and/or top to bottom.
end

--[[ this method randomly masks values in a solved sudoku board. for the
	-- easiest level it will hide 5 cells from each 3x3 subsquare.
	--
	-- this method makes no attempt to ensure a unique solution and simply
	-- (naively) just masks random values. usually there will be only one
	-- solution however, there may be two or more. i've seen boards with as
	-- many as 6 or 7 solutions using this function, though that is pretty
	-- rare.
	--
	-- this method takes two parameters:
	-- 	matrix - the game array completely initialized with the game
	-- 		 data.
	-- 	mask - an array to store the 9x9 mask data. the mask array will
-- 	       contain the board that will be presented to the user.]]
function Sudoku:maskBoardEasy ( matrix, mask ) 
	local i
	local j
	local k
	
	print( "Mask is " .. tostring(mask) )
	
	for i = 1, 81, 1 do
		mask[i] = matrix[i]
	end
	
	-- at this point we have a board with about 20 to 25 hints and a
	-- single solution.
	local dokuline = ""
	
	print( "\n")
	
	for i = 0, 2, 1 do
		for j = 1, 3, 1 do
			-- for each 3x3 subsquare, pick 5 random cells
			-- and mask them.
			for k = 1, 5, 1 do
				local c
				
				repeat
					c = math.random( 9 ) - 1
					print( "Mask at check is " .. (i * 3 + math.floor(c / 3)) * 9 + j * 3 + c % 3)
				until mask[(i * 3 + math.floor(c / 3)) * 9 + j * 3 + c % 3] ~= 0
		
				mask[(i * 3 + math.floor(c / 3)) * 9 + j * 3 + c % 3] = 0
			end
		end
	end
	
	-- at this point we have a board with about 20 to 25 hints and a
	-- single solution.
	
	-- Test output by printing it to the console;/
	for i = 0, 8, 1 do
		for j = 1, 9, 1 do
			--print("Indexing " .. i * 9 + j )
			dokuline = dokuline .. tostring( mask[ i * 9 +  j ] ) .. ','
		end
		dokuline = dokuline .. " Row " .. i .. '\n'

	end
	
	print( dokuline )

end

--[[this method scans all three zones that contains the specified cell
-- and populates an array with values that have not already been used in
-- one of the zones. the order of the values in the array are randomized
-- so the solver may simply iterate linearly through the array to try
-- the values in a random order rather than sequentially.
--
-- self method takes three parameters:
-- 	matrix - the array containing the current state of the puzzle.
-- 	cell - the cell for which to retrieve available values.
-- 	avail - the array to receive the available values. if self
-- 		parameter is nil, self method simply counts the number
-- 		of available values without returning them.
--
-- self method returns the length of the data in the available array.]]
function Sudoku:getAvailable( matrix, cell, avail )
	local i
	local j
	local row
	local col
	local r
	local c

	local arr = {}

	print( "Sudoku:getAvailable Matrix is " .. tostring(matrix) .. " cell is " .. cell .. " avail is " .. tostring(avail) )
	row = math.floor(cell / 9)
	col = cell % 9


	if col == 0 then
		col = 1
	end
	
	if row == 9 then 
		row = 0
	end
	
	print( "Row is " .. row )
	-- row
	for i = 1, 9, 1 do

		j = row * 9 + i

		
	print ( "J is " .. j .. " matrix is " .. tostring(matrix[j]))
		if( matrix[j] > 0 ) then
			arr[ matrix[j] ] = 1
		end
	end

	-- col
	for i = 0, 8 , 1 do

		j = i * 9 + col


		if( matrix[j] > 0) then

		arr[ matrix[j] ] = 1
		end
	end

	-- square
	r = row - row % 3
	c = col - col % 3
	
	if c == 0 then
		c = 1
	end
	
	for i = r, r + 3, 1 do
		for j = c,  c + 3, 1 do
			if matrix[i * 9 + j] > 0 then
			arr[ matrix[i * 9 + j]] = 1
			end
				
			j = 0
	
			if avail ~= nil then		

				for i = 1, 9, 1 do
					if arr[i] == 0 then
						avail[j] = i + 1
						j = j + 1
					end
				end
			else

				for i = 1, 9, 1 do
					if arr[i] == 0 then
						j = j + 1
					end
					
					return j
				end
			end
		end
	end
		
	if j == 0 then 
		return 0
	end
		
	for i = 1, 18, 1 do

		r = math.random( j )
		c = math.random( j )
		row = avail[r]
		avail[r] = avail[c]
		avail[c] = row
	end

	return j
end

--[[ self method is used by the solver to find the next cell to be filled.
-- the cell is chosen by finding a cell with the least amount of
-- available values to try.
--
-- self method takes one parameter:
-- 	matrix - the array containing the current state of the puzzle.
--
-- self method returns the next cell, or -1 if there are no cells left
-- to choose.]]
function Sudoku:getCell ( matrix )

	local cell = -1
	local n = 10
	local i
	local j
	local avail = Matrix.Create(9)

	for i = 1, 81, 1 do

		if matrix[i] == 0 then
			j = self:getAvailable( matrix, i, nil )

			if j < n then
				n = j
				cell = i
			end
	
			if n == 1 then
				break
			end
		end
	end

	return cell
end

--[[this is the actual solver. it implements a backtracking algorithm in
-- which it randomly selects numbers to try in each cell. it starts
-- with the first cell and picks a random number. if the number works in
-- the cell, it recursively chooses the next cell and starts again. if
-- all the numbers for a cell have been tried and none work, a number
-- chosen for a previous cell cannot be part of the solution so we have
-- to back up to the last cell and choose another number. if all the
-- numbers for that cell have also been tried, we back up again. this
-- continues until a value is chosen for all 81 cells.
--
-- this method takes one parameter:
-- 	matrix - the array containing the current state of the puzzle.
--
-- this method returns 1 if a solution has been found or 0 if there was
-- not a solution.]]
function Sudoku:solve( matrix )

	local i
	local j
	local ret = 0
	local cell = self:getCell( matrix )
	local avail = Matrix.Create(9)
	
	print("Sudoku:solve( matrix )" .. tostring(matrix) .. " cell is " .. cell )
	-- since self is the solver that is following the sudoku rules,
	-- if getCell returns -1 we are guaranteed to have found a valid
	-- solution. in self case we just return 1 (for 1 solution, see
	-- enumSolutions for more information).
	if cell == -1 then
		return 1
	end


	j = self:getAvailable( matrix, cell, avail )
		
	for i = 1, j, 1 do
	print ( "Cell is " .. cell .. " While avail[i] is " .. tostring(avail[i]))
		matrix[cell] = avail[i]

		-- if we found a solution, return 1 to the caller.
		if self:solve( matrix ) == 1 then
			return 1
		end
			
		-- if we haven't found a solution yet, try the next
		-- value in the available array.
	end

	-- we've tried all the values in the available array without
	-- finding a solution. reset the cell value back to zero and
	-- return zero to the caller.
	matrix[cell] = 0
		
	return 0
end

--[[self method counts the number of possible solutions for a given
-- puzzle. self uses the same algorithm as the solver but tries all
-- the available values for all the cells incrementing a count every
-- time a new solution is found. self method is used by the mask
-- function to ensure there is only one solution to the puzzle.
--
-- self method performs well for a puzzle with 20 or so hints. do not
-- try self function on a blank puzzle (zero hints). there is not enough
-- time remaining in the physical universe to enumerate all the possible
-- sudoku boards. when self method returns, the puzzle passed in is
-- restored to its original state.
--
-- self method takes one parameter:
-- 	matrix - the array containing the current state of the puzzle.
--
-- self method returns the number of solutions found or 0 if there was
-- not a solution.]]
function Sudoku:enumSolutions( matrix )

	local i
	local j
	local ret = 0
	local cell = self:getCell( matrix )

	-- if getCell returns -1 the board is completely filled which
	-- means we found a solution. return 1 for this solution.
	if cell == -1 then
		return 1
	end
	
	local avail = Matrix.Create(9)


	j = self:getAvailable( matrix, cell, avail )
		
	for i = 1,  j, 1 do
	
		-- we try each available value in the array and count
		-- how many solutions are produced.
		self.matrix[cell] = avail[i]

		ret = ret + self.enumSolutions( matrix )

		-- for the purposes of the mask function, if we found
		-- more than one solution, we can quit searching now
		-- so the mask algorithm can try a different value.
		if ret > 1 then
			break
		end
	end
	
	self.matrix[cell] = 0
	
	return ret
end

--[[this method generates a minimal sudoku puzzle. minimal means that no
-- remaining hints on the board may be removed and still generate a
-- unique solution. when self method returns the resulting puzzle will
-- contain about 20 to 25 hints that describe a puzzle with only one
-- solution.
--
-- self method takes two parameters:
-- 	matrix - the game array completely initialized with the game
-- 		 data.
-- 	mask - an array to store the 9x9 mask data. the mask array will
-- 	       contain the board that will be presented to the user. ]]
function Sudoku:maskBoard( mask, matrix )

	local i
	local j
	local k
	local r
	local c
	local n = 0
	local a
	local hints = 0
	local cell
	local val
	local avail = Matrix.Create(9)
	local tried = Matrix.Create(81)
	local dokuline

	-- start with a cleared out board
	self.mask:Clear()

	-- randomly add values from the solved board to the masked
	-- board, picking only cells that cannot be deduced by existing
	-- values in the masked board.
	--
	-- the following rules are used to determine the cells to
	-- populate:
	-- 1. based on the three zones to which the cell belongs, if
	-- more than one value can go in the cell (i.e. the selected
	-- cell value and at least one other value), check rule two.
	-- 2. for each zone, if the selected value could go in another
	-- free cell in the zone then the cell may be selected as a
	-- hint. self rule must be satisfied by all three zones.
	--
	-- both rules must pass for a cell to be selected. once all 81
	-- cells have been checked, the masked board will represent a
	-- puzzle with a single solution.
	repeat
		-- choose a cell at random.
		repeat
			cell = math.random( 81 ) 
		until ( mask[cell] == 0) or (tried[cell] == 0) 
			
		val = matrix[cell]

		-- see how many values can go in the cell.
		i = self:getAvailable(  mask, cell, nil )

		if i > 1 then
		
			-- two or more values can go in the cell based
			-- on values used in each zone.
			--
			-- check each zone and make sure the selected
			-- value can also be used in at least one other
			-- cell in the zone.
			local cnt
			local row = math.floor(cell / 9)
			local col = cell % 9

			cnt = 0 -- count the cells in which the value may be used.

			-- look at each cell in the same row as the
			-- selected cell.
			for i = 1, 9, 1 do
					
				-- don't bother looking at the selected
				-- cell. we already know the value will
				-- work.
				if i ~= col then
					j = row * 9 + i -- j stores the cell index

					-- if the value is already filled, skip
					-- to the next.
					if mask[j] == 0 then
						-- get the values that can be used in
						-- the cell.
						a = self:getAvailable( mask, j, avail )
	
						-- see if our value is in the available
						-- value list.
						for j = 1, a, 1 do
							if avail[j] == val then
								cnt = cnt + 1
								break
							end
								
							avail[j] = 0
						end
					end
				end
			end

		
			--f the count is greater than zero, the
			-- selected value could also be used in another
			-- cell in that zone. we repeat the process with
			-- the other two zones.
			if cnt > 0 then
				-- col
				cnt = 0
					
				for i = 1, 9, 1 do
					if i ~= row then
						j = i * 9 + col
							
						if mask[j] == 0 then
							a = self:getAvailable( mask, j, avail )
								
							for j = 1, a, 1 do
								if avail[j] == val  then
									cnt = cnt + 1
									break
								end
									
								avail[j] = 0
							end
						end
					end
				end
			
			--if the count is greater than zero,
				-- the selected value could also be used
				-- in another cell in that zone. we
				-- repeat the process with the last
				-- zone.
				if cnt > 0 then
				
					-- square
					cnt = 0
					r = row - row % 3
					c = col - col % 3
					
					for i = r, r + 3, 1 do
						for j = c, c + 3, 1 do
						
							if (i ~= row) and ( j ~= col ) then


								k = i * 9 + j
								
								if mask[k] == 0 then

									a = self.getAvailable( mask, k, avail)
									
									for k = 1, a, 1 do

										if avail[k] == val then

											cnt = cnt + 1
											break
										end
										
										avail[k] = 0
									end
								end
							end
						end
					end
					
					if cnt > 0 then
					
						mask[cell] = val
						hints = hint + 1
					end
				end
			end 
		end 

		tried[cell] = 1
		n = n + 1

	until n == 81

	-- at this point we should have a masked board with about 40 to
	-- 50 hints. randomly select hints and remove them. for each
	-- removed hint, see if there is still a single solution. if so,
	-- select another hint and repeat. if not, replace the hint and
	-- try another.
	repeat
		repeat
			cell = math.random( 81 )

		until ( mask[cell] ~= 0) or (tried[cell] ~= 0)

		
		val = mask[cell]

		print( "Value is " .. val )

		local t = self
		local solutions = 0

		mask[cell] = 0
		solutions = self:enumSolutions( mask )

		if solutions > 1 then
			mask[cell] = val
		end
			
		tried[cell] = 0
		hints = hints -1 

		print( "Hints " .. hints )
	until hints <= 0 

	-- at this point we have a board with about 20 to 25 hints and a
	-- single solution.
	local dokuline
	
	-- Test output by printing it to the console
	for i = 0, 8, 1 do
		for j = 1, 9, 1 do
			dokuline = dokuline .. tostring( self.mask[ i * 9 +  j ]) .. ','
		end
		dokuline = dokuline .. " Row " .. i .. '\n'
		print( dokuline )
	end

end


--[[self method checks whether a value will work in a given cell. it
-- checks each zone to ensure the value is not already used.
--
-- self method takes three parameters:
-- 	row - the row of the cell
-- 	col - the column of the cell
-- 	val - the value to try in the cell
--
-- self method returns true if the value can be used in the cell, false
-- otherwise.]]
function Sudoku:_checkVal(matrix, row, col, val) 
		local r
		local c
		
		-- check each cell in the row to see if the value already
		-- exists in the row. do not look at the value of the cell in
		-- the column we are trying. repeat for each zone.
		for i = 1, 9, 1 do
			if((i ~= col) and (matrix[row * 9 + i] == val)) then
				return false
			end
		end

		-- check col
		for i = 1, 9, 1 do
			if((i ~= row + 1) and (matrix[( i - 1 ) * 9 + col] == val)) then
				return false
			end
		end
		
		-- check square
		r = row - row % 3
		c = col - col % 3
		
		if c == 0 then
			c = 1
		end
			
		if r == 0 then
			r = 1
		end
		
		--print("R is " .. r .. " C is " .. c )
		
		for i = r, r + 2,  1 do
			--print( "I is " .. i )
			for j = c,  c + 2,  1 do
				--print ( "Index is " .. i  * 9 + j)
				if ( ((i ~= ( row + 1 ))or (j ~= col)) and (matrix[(i - 1) * 9 + j] == val)) then
					return false
				end
			end
		end
		
		return true
	end


-- 'public' methods

--[[self method checks whether a value will work in a given cell. it
-- checks each zone to ensure the value is not already used.
--
-- self method takes three parameters:
-- 	row - the row of the cell
-- 	col - the column of the cell
-- 	val - the value to try in the cell
--
-- self method returns true if the value can be used in the cell, false
-- otherwise.]]
function Sudoku:checkVal(row, col, val)
	row = row - 1
	return self:_checkVal(self.matrix, row, col, val)
end

--[[ self method sets the value for a particular cell. self is called by
-- the user interface when the user enters a value.
--
-- self method takes three parameters:
-- 	row - the row of the cell
-- 	col - the column of the cell
-- 	val - the value to enter in the cell]]
function Sudoku:setVal(row, col, val)
	self.matrix[row * 9 + col] = val
end

--[[self method gets the value for a particular cell. self is called by
-- the user interface for displaying the contents of a cell.
--
-- self method takes two parameters:
-- 	row - the row of the cell
-- 	col - the column of the cell
--
-- self method returns the value of the cell at the specified location.]]
function Sudoku:getVal(row, col)

	return self.matrix[row * 9 + col]
end

	-- self method initializes a new game using the solver to generate the
	-- board.
function Sudoku:_newGame() 
		local i
		local hints = 0
		local mask = Matrix.Create(81)

		-- clear out the game matrix.
		self.matrix:Clear()

		-- call the solver on a completely empty matrix. self will
		-- generate random values for cells resulting in a solved board.
		self:solve(self.matrix)

		-- generate hints for the solved board. if the level is easy,
		-- use the easy mask function.
		if self.level == 0 then
			self:maskBoardEasy(self.matrix, mask)

		else
		
			-- the level is medium or greater. use the advanced mask
			-- function to generate a minimal sudoku puzzle with a
			-- single solution.
			self:maskBoard(self.matrix, mask)

			-- if the level is medium, randomly add 4 extra hints.
			if ( self.level == 1) then
			
				for i = 1, 4, 1 do

					repeat				
						local cell = math.random( 81 )
					until mask[cell] == 0

					mask[cell] = self.matrix[cell]
				end
			end
		end

		-- save the solved matrix.
		self.save = self.matrix

		-- set the masked matrix as the puzzle.
		self.matrix = mask

		--timeDiff.start()
	end

	--self.done

function Sudoku:_doHints(matrix, mask, tried, hints)
	
		-- at this point we should have a masked board with about 40 to
		-- 50 hints. randomly select hints and remove them. for each
		-- removed hint, see if there is still a single solution. if so,
		-- select another hint and repeat. if not, replace the hint and
		-- try another.
		if hints > 0 then

			repeat
				cell = math.random( 81 )
			until((mask[cell] ~= 0) or (tried[cell] ~= 0))

			val = mask[cell]

			local t = self
			local solutions = 0

			mask[cell] = 0
			solutions = self.enumSolutions(mask)
			--console.log("timeout")

			if solutions > 1 then
				mask[cell] = val
			end
		
			tried[cell] = 0
			hints = hint - 1
			--local t = self
			--setTimeout(function()t._doHints(matrix, mask, tried, hints)end, 50)
		else

			self.save = self.matrix
			self.matrix = mask
			--self:done()
		end

		--console.log(hints)

		-- at self point we have a board with about 20 to 25 hints and a
		-- single solution.
	end

function Sudoku:_doMask(matrix, mask)

	local i
	local j
	local k
	local r
	local c
	local n = 0
	local a
	local hints = 0
	local cell
	local val
	local avail = Matrix.Create(9)
	local tried = Matrix.Create(81)


	-- start with a Cleared out board
	mask.Clear()

	-- randomly add values from the solved board to the masked
	-- board, picking only cells that cannot be deduced by existing
	-- values in the masked board.
	--
	-- the following rules are used to determine the cells to
	-- populate:
	-- 1. based on the three zones to which the cell belongs, if
	-- more than one value can go in the cell (i.e. the selected
	-- cell value and at least one other value), check rule two.
	-- 2. for each zone, if the selected value could go in another
	-- free cell in the zone then the cell may be selected as a
	-- hint. self rule must be satisfied by all three zones.
	--
	-- both rules must pass for a cell to be selected. once all 81
	-- cells have been checked, the masked board will represent a
	-- puzzle with a single solution.
	repeat

		-- choose a cell at random.
		repeat
			cell = math.random( 81 )
		until (mask[cell] == 0) or (tried[cell] == 0)
			
		val = matrix[cell]

		-- see how many values can go in the cell.
		i = self:getAvailable(mask, cell, nil)

		if i > 1 then
		
			-- two or more values can go in the cell based
			-- on values used in each zone.
			--
			-- check each zone and make sure the selected
			-- value can also be used in at least one other
			-- cell in the zone.
			local cnt
			local row = math.floor(cell / 9)
			local col = cell % 9

			-- count the cells in which the value may be used.

			cnt = 0 

			-- look at each cell in the same row as the
			-- selected cell.
			for i = 1, 9, 1 do
				
				-- don't bother looking at the selected
				-- cell. we already know the value will
				-- work.
				if i ~= col then
					j = row * 9 + i -- j stores the cell index

					-- if the value is already filled, skip
					-- to the next.
					if mask[j] == 0 then 

						-- get the values that can be used in
						-- the cell.
						a = self.getAvailable( mask, j, avail )
	
						-- see if our value is in the available
						-- value list.
						for j = 1,  a,  1 do

							if avail[j] == val then

								cnt = cnt + 1
								break
							end
							
							avail[j] = 0
						end
					end
				end
			end

			-- if the count is greater than zero, the
			-- selected value could also be used in another
			-- cell in that zone. we repeat the process with
			-- the other two zones.
			if cnt > 0 then
				
				-- col
				cnt = 0
					
				for i = 1, 9, 1 do

					if i ~= row then

						j = i * 9 + col
				
						if mask[j] == 0 then

							a = self.getAvailable(mask, j, avail)
								
							for j = 1, a, 1 do

								if avail[j] == val then

									cnt = cnt + 1
									break
								end
									
								avail[j] = 0
							end
						end
					end
				end

				-- if the count is greater than zero,
				-- the selected value could also be used
				-- in another cell in that zone. we
				-- repeat the process with the last
				-- zone.
				if cnt > 0 then
				
					-- square
					cnt = 0
					r = row - row % 3
					c = col - col % 3
						
					for i = r, r + 3,  1 do
						for j = c, c + 3,  1 do

							if (i ~= row) and (j ~= col) then
								k = i * 9 + j

								if mask[k] == 0 then
									a = self.getAvailable(mask, k, avail)
										
									for k = 1, a,  1 do
										if avail[k] == val then
											cnt = cnt + 1
											break
										end
											
										avail[k] = 0
									end
								end
							end
						end
					end

			
					if cnt > 0 then

						mask[cell] = val
						hints = hints + 1
					end
				end
			end
		end

		tried[cell] = 1
		n = n + 1
	
	until n == 81
	
	local t = self
	--setTimeout(function()t._doHints(matrix, mask, tried, hints)end, 50)
end

function Sudoku:newGame() 
	local i
	local hints = 0
	local cell
	local mask = Matrix.Create( 81 )

	-- clear out the game matrix.
	self.matrix:Clear()

	-- call the solver on a completely empty matrix. self will
	-- generate random values for cells resulting in a solved board.
	self:shuffle( self.matrix )

	-- generate hints for the solved board. if the level is easy,
	-- use the easy mask function.
	if self.level == 0 then
		self:maskBoardEasy( self.matrix, mask )

		-- save the solved matrix.
		self.save = self.matrix

		-- set the masked matrix as the puzzle.
		self.matrix = mask

		--timeDiff.start()
		--self:done()
	else
		-- the level is medium or greater. use the advanced mask
		-- function to generate a minimal sudoku puzzle with a
		-- single solution.
		self:_doMask(self.matrix, mask)

		-- if the level is medium, randomly add 4 extra hints.
		if self.level == 1 then
			for i = 1, 4, 1 do

				repeat
					cell = math.random( 81 )
				until mask[cell] == 0 

				mask[cell] = self.matrix[cell]
			end
		end
	end
end

-- self method solves the current game by restoring the solved matrix.
-- if the original unmodified masked matrix was saved, self function
-- could call the solve method which would undo any wrong player guesses
-- and actually solve the game.
function Sudoku:solveGame() 
	self.matrix = self.save
end

-- self method determines wether or not the game has been completed. it
-- looks at each cell and determines whether or not a value has been
-- entered. if not, the game is not done. if a value has been entered,
-- it calls checkVal() to make sure the value does not violate the
-- sudoku rules. if both checks are passed for each cell in the board
-- the game is complete.
function Sudoku:gameFinished()

	for i = 1, 9, 1 do

		for j = 1, 9, 1 do

			local val = self.matrix[i * 9 + j]
			
			if((val == 0) or (self:_checkVal(self.matrix, i, j, val) == false)) then
				return 0
			end
		end
	end

	return nil --timeDiff.end()
end

return Sudoku