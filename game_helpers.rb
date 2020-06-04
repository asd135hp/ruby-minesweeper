
######################################## GAME FUNCTION HELPERS ########################################
# Just a helper function for main window object/game. It helps in both single player and multiplayer  #
#######################################################################################################

############################### SINGLE PLAYER ###############################
# function equals to 'margin : 100 auto 0 auto' in HTML
# a procedure to auto-margin the board in single player mode, according to its width, height and square size
def get_client_window_margin width, height, size
  width_size  = width * size
  height_size = height * size
  info_size   = 100

  margin_x    = (WINDOW_WIDTH - width_size) / 2
  margin_y    = (WINDOW_HEIGHT - height_size - info_size) / 2 + info_size   # margin for informations display above the board

  { :x => margin_x, :y => margin_y }
end

# get level info
def get_level_info level
  # returning value : [width, height, square_size, flags/bombs]
  case level.to_i
  when 1
    # easy
    [10, 10, 40, 10]
  when 2
    # medium
    [20, 15, 34, 35]
  when 3
    # hard
    [35, 17, 27, 100]
  end
end


############################# FINAL MESSAGES AFTER GAMES (FOR BOTH MULTIPLAYER & SINGLEPLAYER) #############################
# to craft final message to put it to the screen when the game ends
def craft_message_after_game game_id, ui_stages, player
  # this is a must since multiple threads will call this function and overlapping situation is always happenning
  unless FLAGS[:is_finish_message_set]
    timer     = player.timer
    bombs     = player.bombs
    flags     = player.flags
    level     = player.level
    is_host   = FLAGS[:is_host]
    is_win    = FLAGS[:is_win]
    is_multi  = FLAGS[:is_multiplayer]

    time_str    = time_converter(timer)
    used_flag   = bombs - flags
    rank        = get_rank(level, timer, used_flag, bombs, is_win)
    game_state  = is_host ? (is_win ? 0 : 1) : (is_win ? 1 : 0)

    # set false here to not tick the timer anymore
    FLAGS[:is_game_started] = false

    # set out messages
    title       = "You #{is_win ? "win" : "lose"}!"
    final_info  = is_multi ? "Your time: #{time_str}\nRank: #{rank}" : "Time: #{time_str}\nUsed flags: #{used_flag}\nRank: #{rank}"
    # those lines below can not be called inside any threads as the texts will become really weird
    components = ui_stages[Stage::END_MESSAGE]
    change_button_text(components[0], title)
    change_button_text(components[1], final_info)
    log_everything("It comes to an end")
    log_everything("You #{is_win ? "WIN :3" : "LOSE :d"} in #{is_multi ? "multiplayer" : "single player"} mode")

    # send the last message to server if it is in the multiplayer mode
    craft_firebase_command("minesweeper/game#{game_id}/who_win.json", "PUT", game_state).join if is_multi

    FLAGS[:is_finish_message_set] = true
  end
end

# instead of lazily calling craft_message_after_game while even inside the thread, call this from update function instead
# it will signal the end of the game to the current window object so that the next functions will draw out end messages instead
def signal_the_end_of_game is_win, change_stage_callable, is_multiplayer = false
  # sleep for 0.5 seconds so that user can see how they lose/win (well, it's their opponent to be more accurate)
  sleep(0.5)

  # set variables to be checked upon
  # all flags are set first so that the main message comes first, not some dummy texts
  # this refers to the importance of procedural code
  log_everything(
    "Called from somewhere that says is_win => #{is_win ? "true" : "false"} and is_multiplayer => #{is_multiplayer ? "true" : "false"}"
  )
  FLAGS[:is_win]                = is_win
  FLAGS[:is_multiplayer]        = is_multiplayer
  FLAGS[:is_finish_message_set] = false

  # changes back to end message
  change_stage_callable.call()
end

############## RANK CALCULATION ##############
# just for fun
# also, it could make game more involving to user
def get_rank level, time, used_flag, max_flag, win
  return 'F for Failing unexpectedly' if not win

  rank_number = calculate_game_rank(level, time, used_flag, max_flag)
  case rank_number
  when 0
    '??? for Are you humanely conscious?'
  when 1
    'A for Admirable'
  when 2
    'B for Badly well done'
  when 3
    'C for Considerably neutral'
  when 4
    'D for Desperately medium rare'
  when 5
    'E for Execellently bad'
  when 6
    'F for Failing to be the best'
  else
    'X for X-tremely sorry, nothing is here for you'
  end
end
def calculate_game_rank level, time, used_flag, max_flag
  # 1 - Easy, 2 - Medium, 3 - Hard, -1 - Multiplayer
  # generally, it is 75 seconds before reaching the best rank possible
  # (if they keep playing 10x10 or low bombs then this message appears alot)
  return 0 if ((level == 1 and time <= 15) or (level == 2 and time <= 45) or
              (level == 3 and time <= 100) or (level == -1 and time <= 75)) and used_flag == 0

  # 1 - Easy: 45s / rank, 2 - Medium: 75s / rank, 3 - Hard: 105s / rank, else - Multiplayer: 90s / rank
  time_per_rank = (level == 1 ? 45 : (level == 2 ? 75 : (level == 3 ? 105 : 90))).to_f
  # for flag, max_flag / 6 per rank
  flag_per_rank = 6.0 / max_flag.to_f

  # the rank is a floor of average of time and flag used
  ((time.to_f / time_per_rank + used_flag.to_f * flag_per_rank) / 2).to_i
end




############################# MULTIPLAYER MODE #############################
# this function just to calculate bomb limit that does not make the game unplayable
# in multiplayer mode as a host, player will choose width and height of the board
# however, decreasing any of them will result in the change in maximum bombs possible
# this procedure is here to mitigate that situation
def calculate_current_bomb_limit multiplayer_game_data
  data            = multiplayer_game_data
  current_width   = data["board_width"]
  current_height  = data["board_height"]
  current_area    = current_width * current_height
  width_limit     = data["board_width_limit"][1]
  height_limit    = data["board_height_limit"][1]
  limit_area      = width_limit * height_limit

  # calculation :
  # current selecting area - floor(real percentage between current and limited area * 15)
  new_current_limit = current_area - ((current_area.to_f / limit_area.to_f) * 15).to_i

  # if current selecting bomb number passes current calculated limit,
  # make limit the current bomb number instead!
  data["bombs"] = new_current_limit if data["bombs"] > new_current_limit

  new_current_limit
end

# calculate number of selected bomb when clicking to certain time
def calculate_bomb_acceleration data
  acceleration = 1
  # reset data first then check everything after
  # interval : 1250ms (1.25 secs)
  if data[:start_time] && Gosu.milliseconds - data[:start_time] >= 1250
    data[:click_number] = 0
    acceleration = 1
  end

  # each case of click number yields different acceleration
  case data[:click_number].to_s
  when /1[0-8]/
    acceleration = 2
  when /19|2[0-6]/
    acceleration = 3
  when /2[7-9]|3[0-4]/
    acceleration = 4
  when /3[5-9]|[4-9][0-9]/
    acceleration = 5
  when ""
    data[:click_number] = 0
  end

  data[:click_number] = 0 if data[:click_number] >= 100

  # saves data for next comparison
  data[:start_time] = Gosu.milliseconds
  data[:click_number] += 1

  # return acceleration value
  acceleration
end

# change data upon clicking in multiplayer mode
def alter_multiplayer_info key, component, bomb_number_component, comparing_function, increment
  # only bombs value has this privilege to get acceleration in a separate function
  accel       = key == "bombs" ? calculate_bomb_acceleration(MODIFIABLE_MULTIPLAYER_DATA) : 1
  new_data    = MODIFIABLE_MULTIPLAYER_DATA[key] + (increment ? accel : -accel)
  data_limit  = MODIFIABLE_MULTIPLAYER_DATA["#{key}_limit"]

  if data_limit && comparing_function.call(new_data, data_limit)
    # it is in the limit => acceptable
    change_button_text(component, new_data.to_s)

    # change current ui text representation
    MODIFIABLE_MULTIPLAYER_DATA[key] = new_data

    # if the key is not bombs then calculate the new limit
    # however, the text is not changed tho
    if key != "bombs" and bomb_number_component != nil
      MODIFIABLE_MULTIPLAYER_DATA["bombs_limit"][1] = calculate_current_bomb_limit(MODIFIABLE_MULTIPLAYER_DATA)
      change_button_text(bomb_number_component, MODIFIABLE_MULTIPLAYER_DATA["bombs"])
    end
  end
end

# calculate the maximum possible board's square size from customizing data for multiplayer (for main player only)
def calculate_maximum_square_size width, height, margins
  # maximum width is trimmed by opponent's view width
  main_player_view_width        = WINDOW_WIDTH - OPPONENT_VIEW_WIDTH
  maximum_width                 = main_player_view_width - margins[:x] * 2
  maximum_height                = WINDOW_HEIGHT - margins[:y] - margins[:y_bottom]
  maximum_square_size_in_width  = maximum_width / width
  maximum_square_size_in_height = maximum_height / height

  # get the smallest possible size to fit the 'viewable' screen
  best_square_size = maximum_square_size_in_width >= maximum_square_size_in_height ?
    maximum_square_size_in_height :
    maximum_square_size_in_width

  # readjust player's board to the center
  margins[:x] = (main_player_view_width - width * best_square_size).to_f / 2
  margins[:y] += (WINDOW_HEIGHT - margins[:y] - height * best_square_size) / 2

  # return new square size
  best_square_size
end


########################### GAME STATE JUDGEMENT - MULTIPLAYER ###########################
# determine who wins and display which message (actually, it is someone wins)
def determine_message_from_game_state ui, game_id, state
  # start the game if it is in playing state
  # else the game loop will end
  FLAGS[:is_game_started] = state == -1

  result              = true
  is_host             = FLAGS[:is_host]
  end_screen_callable = lambda { change_UI_stage(4, ui) }

  case state
  when 0
    # refers to host wins
    is_win = is_host ? true : false
    log_everything("Host wins")
    signal_the_end_of_game(is_win, end_screen_callable, true)
  when 1
    # refers to other player wins
    is_win = is_host ? false : true
    log_everything("Player wins")
    signal_the_end_of_game(is_win, end_screen_callable, true)
  when -1
    log_everything("Playing...")
    result = false
  when -2
    log_everything("Waiting~~~~~")
    result = false
  when -3
    log_everything("Communication interruption occurred. You win by default!")
    signal_the_end_of_game(true, end_screen_callable, true)

    # because if other user exits, the remain user will be the only one who would call this function
    # so clean up game session here is feasible
    finish_game_session(game_id)
    result = true
  else
    log_everything("Unable to retrieve game's state. What's left: #{state.to_s}")
    result = false
  end

  result
end