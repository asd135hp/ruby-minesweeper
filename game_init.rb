########################################## MAIN GAME FUNCTIONS ##########################################
# Game initialization - main game functions that can be used to initialize game objects everywhere      #
#########################################################################################################
## Initializing game
def initialize_board width, height
  Array.new(height).map{
    Array.new(width).map{ 0 }
  }
end
def initialize_board_view width, height
  # covered is identified with 'c'
  # uncovered is identified with another values
  Array.new(height).map{
    Array.new(width).map{ 'c' }
  }
end

# none colliding bomb positions
def get_bomb_positions board, bomb_number
  bombs = Array.new
  width = board[0].length
  height = board.length

  for bomb_index in 1..bomb_number
    # prevent colliding bomb positions by looping as much as it can to get it right
    loop do
      x = rand(width - 1)
      y = rand(height - 1)

      if board[y][x] != -1
        board[y][x] = -1                # indexing bomb inside the board
        bombs << { :x => x, :y => y }   # pushing bomb position
        break
      end
    end
  end

  # log bombs positions
  log_everything("Bombs created: [#{bombs.each{ |bomb| "(#{bomb[:x]}, #{bomb[:y]})"}.join(', ')}]", true)

  bombs
end

# distribute bombs across the board
# discard any out-of-bound checks
def distribute_bombs board, bomb_positions
  # size is determine the same way as when initializing the board
  width = board[0].length
  height = board.length

  bomb_positions.each{ |bomb|
    for col_index in -1..1
      for row_index in -1..1
        new_x = bomb[:x] + row_index
        new_y = bomb[:y] + col_index

        # skips if either out-of-bound or the square contains a bomb
        next if board[new_y][new_x] == -1 or
          (new_x < 0 or new_y < 0) or
          (new_x >= width or new_y >= height)

        board[new_y][new_x] += 1
      end
    end
  }
end


## Game play
#
# Reveals covered squares
#
# If covered square contains a number, just reveal that square
# Else if covered square is a bomb, return nil
# Else reveals all adjacent squares until all above conditions are satisfied (except for bombs)
def reveal_squares board, board_view, x, y
  # pre-check
  threshold_x = board[0].length - 1
  threshold_y = board.length - 1

  # utilise the nature of short-circuit logic check
  # if flag check comes first then <Unhandled error> will raise
  return if (x < 0 or y < 0) or (x > threshold_x or y > threshold_y) or board_view[y][x] == 'f'

  square_value = board[y][x]

  # only if the square is covered then the check will be taken place
  # this is to prevent stack overflow
  if board_view[y][x] == 'c' and board_view[y][x] != 'f'
    # copy value from original board to board view
    # this is for easier drawing method
    board_view[y][x] = square_value

    # if square contains empty value, check recursively across the board
    if square_value == 0
      # recursively check surrounding squares
      for col_index in -1..1
        for row_index in -1..1
          new_x = x + row_index
          new_y = y + col_index

          reveal_squares(board, board_view, new_x, new_y)
        end
      end
    end
  end

  # return square's value to directly get bomb value in case user get a bomb
  square_value
end

# reveal all possible bombs 
def reveal_bombs board_view, bomb_positions
  bomb_positions.each { |bomb|
    board_view[bomb[:y]][bomb[:x]] = -1
  }
end

# calculate remaining covered squares that hide bombs
def get_covered_squares board_view
  num_of_squares = 0

  # complexity : O(n^2)
  # if there is a better way than checking covered squares with O(n^2) each time the mouse clicks on the board, then I will take it
  # why does this works?
  # because even if the player uses all of available flags, there are covered squares that they need to click on, which will be
  # either a number or a bomb, no matter what.
  # if the flags are all in the positions of the bombs then they just need to click the remaining squares to complete the puzzle 
  board_view.each{ |row|
    row.each{ |value|
      num_of_squares += 1 if value == 'c' or value == 'f'
    }
  }

  num_of_squares
end
