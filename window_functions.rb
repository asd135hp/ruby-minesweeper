############################################# Windows #############################################
#                          From here is window region. Enter with caution!                        #
# Trade back of transforming from OOP to structural is a really high and bad cohesion...          #
# Some functions have *args as argument list because it is expected to be callable from outside   #
###################################################################################################

# initialize the window object
def initialize_window window
  window.ui = initialize_ui(read_from_map_file, [
    define_flexible_button(20, 20, "Your game # will be ready shortly", { :font_size => 20, :border_thickness => 0 }),
    define_flexible_button(0, 0, "Loading...", {
      :font_size => 55, :horizontal_align => 0.5, :vertical_align => 0.5, :border_thickness => 0
    })
  ])

  window.player = SinglePlayerData.new
  window.database = Database.new

  # avoiding collisions that turns out to be letting a thread running independently without properly ending it
  window.current_running_threads = []
end




########################### REUSABLE WINDOW FUNCTIONS ###########################
# change ui stage followed by provided level value
# if there is an error then it definitely relates to this function with self being Window object or not(if not specified)
def change_UI_stage level, *args
  ui = args[0]

  # set UI stage value
  ui.level = _level = level.to_i
  log_everything("Changed UI stage to stage ##{level}")

  # if UI_stage is for playing then update inconsistent-components such as timer text and flag text
  if _level == 3 or _level == 8
    ui.playing_mode.timer_texture = ui.stages[_level - 1][1]
    ui.playing_mode.flags_texture = ui.stages[_level - 1][3]
  end
end

# Intializing a brand new game
def initialize_game player
  player.timer           = 0
  player.board           = initialize_board(player.board_width, player.board_height)
  player.board_view      = initialize_board_view(player.board_width, player.board_height)
  player.bombs_positions = get_bomb_positions(player.board, player.bombs)
  distribute_bombs(player.board, player.bombs_positions)

  FLAGS[:is_game_started] = false

  # prevent updating 10 times a sec for timer and flag number
  FLAGS[:info_not_set] = true
end

# get board's x and y position from board's margin from window's left and top border
def get_clicked_square player, mouse_x, mouse_y
  margin_x = player.margins[:x].to_f
  margin_y = player.margins[:y].to_f
  size = player.square_size.to_f
  x = ((mouse_x - margin_x).to_f / size).to_i
  y = ((mouse_y - margin_y).to_f / size).to_i

  return (x < 0 or y < 0 or x > player.board_width or y > player.board_height) ? nil : [x, y]
end

# board drawing to the window
def draw_board_view board_view, margins, square_size, flip_90_deg = false
  # draw game
  if board_view and margins and square_size
    row_index = 0
    board_view.each{ |row|
      col_index = 0
      row.each{ |value|
        x = margins[:x] + square_size * (flip_90_deg ? row_index : col_index)
        y = margins[:y] + square_size * (flip_90_deg ? col_index : row_index)

        # resize image
        image = get_square_image(value)
        scale_x = square_size.to_f / image.width.to_f
        scale_y = square_size.to_f / image.height.to_f
        image.draw(x, y, ZOrder::GAME, scale_x, scale_y)

        col_index += 1
      }
      row_index += 1
    }
  end
end




################################# SINGLE PLAYER #################################
# start playing with given level (single player)
def set_level_info level, *args
  ui      = args[0]
  player  = args[1]
  info    = get_level_info(level)

  player.level                  = level.to_i
  player.board_width   = bw     = info[0]
  player.board_height  = bh     = info[1]
  player.square_size   = ss     = info[2]
  player.flags = player.bombs   = info[3]

  change_UI_stage(3, ui)
  player.margins = get_client_window_margin(bw, bh, ss)
  initialize_game(player)
end




# ############################ Start hosting game ############################
def multiplayer_hosting *args
  change_UI_stage(7, args[0])

  multiplayer_data = MODIFIABLE_MULTIPLAYER_DATA
  multiplayer_data["bombs_limit"][1] = calculate_current_bomb_limit(multiplayer_data)
end

# this is for action of buttons in hosting for customize the game
def increase_data symbol, component_at, bomb_number_component_at, *args
  ui = args[0]
  modifiable_ui_data = ui.stages[Stage::MULTIPLAYER_DATA]

  alter_multiplayer_info(
    symbol,
    modifiable_ui_data[component_at.to_i],
    bomb_number_component_at && modifiable_ui_data[bomb_number_component_at.to_i],
    lambda { |new_data, limit| new_data <= limit[1] },
    true
  )
end

def decrease_data symbol, component_at, bomb_number_component_at, *args
  ui = args[0]
  modifiable_ui_data = ui.stages[Stage::MULTIPLAYER_DATA]

  alter_multiplayer_info(
    symbol,
    modifiable_ui_data[component_at.to_i],
    bomb_number_component_at && modifiable_ui_data[bomb_number_component_at.to_i],
    lambda { |new_data, limit| new_data >= limit[0] },
    false
  )
end




# ############################# Real time multiplayer ###############################
# These code do not demonstrate a full-fledged multiplayer system !!!!!             #
# Many problems still present up to its name but let's keep it simple here !        #
# (Message created on 20/4/2020 - A message to limit author's time putting on this) #
#####################################################################################\
# merge multiplayer data from server to current window's resource
def merge_multiplayer_data new_game_data, player, database
  player.board_width          = new_game_data["board_width"].to_i
  player.board_height         = new_game_data["board_height"].to_i
  player.bombs = player.flags = new_game_data["bombs"].to_i
  database.game_id            = new_game_data["game_id"].to_i
end

# start new thread for communication
def start_communication_thread as_host, game_id, board_view, thread_id, ui
  Thread.start(board_view) { |main_player_board_view|
    # set thread id so that received thread data is in order
    Thread.current[:thread_id] = thread_id

    # starts communication as either host or player, depending on 'as_host' variable
    # also, get who wins
    # (0 - host, 1 - player, -1 - yet to finish, -2 - waiting~~~~, -3 - player win by communication interruption)
    result  = communicate_to_server(as_host, game_id, main_player_board_view)
    state   = result[:game_state]

    # if, for some reason, the data we get from server is non-integer (not as we expected)
    # then end this thread right here to save resource
    Thread.current.exit if not state

    # because communicating to server takes time so assigning game state and opponent's board view value will be delayed
    Thread.current[:game_state] = state
    Thread.current[:opponent_board_view] = result[:board_view]

    # determine who won the game
    Thread.current[:someone_wins] = someone_wins = determine_message_from_game_state(ui, game_id, state)

    # logging to debug
    log_everything("Successfully communicate to server with game state: #{state}")
    log_everything("Hey! #{someone_wins ? "Someone wins!" : "Nvm"}")

    # exit thread when finish works so that its status returns false -> for cleaning array
    Thread.current.exit
  } rescue nil  
end

# start to exchange data to server endlessly till someone wins (1 second / request)
def multiplayer_start_exchange_data as_host, game_id, player, ui, current_running_threads
  # start another communication thread
  current_running_threads << Thread.start{
    # start communicating endlessly until someone wins
    # another problem: stalling (not really playing) to download data endlessly -> fill up download quota of my server -> not good
    # solution: can be fixed in the future but for now, don't try to do it
    Thread.current[:someone_wins] = false
    thread_id = 0
    non_collided_exchanges = []

    begin
      # merge received data first (spawning a new thread so that this thread is not blocked)
      Thread.start(Thread.current) { |parent_thread|
        get_multithread_data(non_collided_exchanges, parent_thread)
      } rescue nil

      # start a new communication thread
      new_thread = start_communication_thread(as_host, game_id, player.board_view, thread_id, ui)
      thread_id += 1

      # pushing new exchange thread into list for retrieval
      non_collided_exchanges << new_thread

      # puts thread to sleep for 1 seconds (1 second / request)
      sleep(1)
    end until Thread.current[:someone_wins]

    # exit all scheduled threads
    clear_threads(non_collided_exchanges, false)
    log_everything("End of multiplayer exchanging thread!!!!")
  } rescue nil
end

# set default for opponent data
def set_opponent_initial_data player_board_width, player_board_height, database
  # absolute margin for opponent's board
  margin_x = WINDOW_WIDTH - OPPONENT_VIEW_WIDTH
  # because opponent's board is flipped so board_height is used
  padding_x = (OPPONENT_VIEW_WIDTH - VIEW_SQUARE_SIZE * player_board_height) / 2
  # following map.txt in the last 4 component's definition
  margin_y = 50 + 80 + 30
  # because opponent's board is flipped so board_width is used
  padding_y = (WINDOW_HEIGHT - margin_y - VIEW_SQUARE_SIZE * player_board_width) / 2

  database.opponent_board_view = []
  OPPONENT_VISUAL_DATA[:margins] = { :x => margin_x + padding_x, :y => margin_y + padding_y }
end


# start initialization thread for multiplayer mode
def start_initialization_thread_multiplayer ui, player, database, current_running_threads
  # changes the top-left text of the loading screen so that it does not have previous game_id
  change_button_text(ui.loading_screen[0], "Your game # will be ready shortly")

  Thread.start {
    is_host = FLAGS[:is_host]
    multiplayer_data = {
      "board_width"   => MODIFIABLE_MULTIPLAYER_DATA["board_width"],
      "board_height"  => MODIFIABLE_MULTIPLAYER_DATA["board_height"],
      "bombs"         => MODIFIABLE_MULTIPLAYER_DATA["bombs"]
    }

    # function to be called when game_id is received
    game_id_procedure = lambda { |game_id|
      # change loading text
      Thread.current[:new_queue_info] = "Your game ##{game_id} will be ready shortly"
      log_everything("Top-left information changed with game id ##{game_id}")
    }

    # get game data from server
    game_data = is_host ?
      establish_game_session(multiplayer_data, game_id_procedure) :
      join_available_game_session(game_id_procedure)

    # if game data is not available then don't go further and go back to UI stage 6 - multiplayer modes chooser
    if game_data == -1
      change_UI_stage(6, ui)
      Thread.current.exit
    end

    # merge game data from server to local machine
    merge_multiplayer_data(game_data, player, database)

    # create another thread to exchange data to each other
    # must pass a whole player datafield here because player.board_view here does not refers to an array reference
    multiplayer_start_exchange_data(is_host, database.game_id, player, ui, current_running_threads)

    # set initial game data for opponent
    set_opponent_initial_data(player.board_width, player.board_height, database)

    # set intial flag number (initialize_game does not change flag number)
    Thread.current[:init_flag] = game_data["bombs"].to_i

    # default margin in multiplayer mode
    # this is main player's board margin
    player.margins     = { :x => 20, :y => 90, :y_bottom => 20 }
    player.square_size = calculate_maximum_square_size(player.board_width, player.board_height, player.margins)

    # initialize a new game session
    initialize_game(player)

    # change UI stage and also starts the game
    change_UI_stage(8, ui)
  } rescue nil
end

# start playing in multiplayer either as host or as another player
def multiplayer_start_point as_host, *args
  ui          = args[0]
  thread_pool = args[3]

  # change to loading stage
  change_UI_stage(-1, ui)

  # clear all previous threads (if there are any)
  clear_threads(thread_pool)

  # determine the session to be either host or player
  FLAGS[:is_host] = as_host.to_i == 0

  # set flag to indicate stopping point to update
  # set to false in order for initial data to be processed
  FLAGS[:initial_data_updated] = false

  # run on different thread in order for user to not multi-clicking button -> multiple requests requested -> server poisoning(?)
  thread_pool << start_initialization_thread_multiplayer(*args)
end




########################## FUNCTIONS FOR UPDATE FUNCTION ##########################
def timer_increment ui_flag_texture, ui_timer_texture, player
  if FLAGS[:is_game_started] and Gosu.milliseconds - FLAGS[:time_from_last_update] >= 1000
    player.timer += 1
    time_as_str = time_converter(player.timer)

    # timer always in position 2
    change_button_text(ui_timer_texture, time_as_str)

    # save current time point for next check
    FLAGS[:time_from_last_update] = Gosu.milliseconds
  elsif FLAGS[:info_not_set]
    # set initial numbers to modifiable ui texts inside that ui stage
    change_button_text(ui_flag_texture, player.flags.to_s)
    change_button_text(ui_timer_texture, time_converter(player.timer))
    FLAGS[:info_not_set] = false
  end
end




################################### MOUSE ACTIONS ###################################
def left_mouse_button_action mouse_x, mouse_y, ui, player, database, threads
  case ui.level.to_s
  when /(3|8)/
    end_screen_callable = lambda { change_UI_stage(4, ui) }

    # only occured when UI stage directs to multiplayer mode
    # if the state is other than playing then clicking will do nothing
    multiplayer_thread = threads[1]
    return if ui.level == 8 and multiplayer_thread.fetch(:game_state, -2) != -1

    # start game if user first click to the game in single player mode
    FLAGS[:is_game_started] = true if ui.level == 3 and not FLAGS[:is_game_started]

    # reveal squares based on clicked squares
    position = get_clicked_square(player, mouse_x, mouse_y)

    # lose directly
    if position != nil and reveal_squares(player.board, player.board_view, position[0], position[1]) == -1
      reveal_bombs(player.board_view, player.bombs_positions)
      signal_the_end_of_game(false, end_screen_callable, ui.level == 8)
    end

    # win directly
    signal_the_end_of_game(true, end_screen_callable, ui.level == 8) if get_covered_squares(player.board_view) == player.bombs
  else
    ui.stages[ui.level - 1].each { |component|
      # if there is an action then call it (this class's pointer as parameter lambda functions)
      component.action&.call(ui, player, database, threads) if is_mouse_inside_button?(component, mouse_x, mouse_y)
    } if ui.level > 0
  end
end

def right_mouse_button_action ui_level, ui_flag_texture, mouse_x, mouse_y, player, multiplayer_thread
  if ui_level == 3 or (ui_level == 8 and multiplayer_thread.fetch(:game_state, -2) == -1)
    position = get_clicked_square(player, mouse_x, mouse_y)

    # only set flags to covered squares
    # only unset flags on flagged squares
    if position != nil
      x = position[0]
      y = position[1]

      # toggle flag on covered squares
      if player.board_view[y][x] == 'c' and player.flags != 0
        player.board_view[y][x] = 'f'
        player.flags -= 1
      elsif player.board_view[y][x] == 'f'
        player.board_view[y][x] = 'c'
        player.flags += 1
      end

      # change flag number's display
      change_button_text(ui_flag_texture, player.flags.to_s)
    end
  end
end




################################### CLOSING WINDOW ###################################
# calls only when user closes the window
def upon_closing game_id, ui_level, multiplayer_threads
  # exit currently running threads
  multiplayer_threads.each{ |thread|
    thread[:someone_wins] = true
    thread.join
    log_everything("Joined a thread about line 1823")
  }

  # indicate that communication is interrupted to server
  craft_firebase_command("minesweeper/game#{game_id}/who_win.json", "PUT", -3) if ui_level == 8
end