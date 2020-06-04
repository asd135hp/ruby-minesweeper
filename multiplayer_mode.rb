
############################################## MULTIPLAYER REGION ##############################################
# Nothing much to say. It supports multiplayer wherever the main game functions are implemented.               #
#                                              Enter with caution!                                             #
################################################################################################################
require 'json'

##################################### Multiplayer region ######################################
#                 From here apart is multiplayer region. Enter with caution!                  #
###############################################################################################

PROJECT_NAME = "uni-project-43896"

# Main function for firebase command
#
# Explaination :
#
# This function mainly utilises back-tick in Ruby,
# which executes provided command between those back-ticks with program's default terminal.
# 
# Also, following Firebase REST API at https://firebase.google.com/docs/reference/rest/database:
# 
# GET request: curl https://[PROJECT_ID].firebaseio.com/[PATH].json -> get data in json format
#
# PUT request: curl -X POST -d [data] https://[PROJECT_ID].firebaseio.com/[PATH].json -> write data with json format
#
# POST request: curl -X POST -d [data] https://[PROJECT_ID].firebaseio.com/[PATH].json -> push data with json format
#
# PATCH request: curl -X PATCH -d [data] https://[PROJECT_ID].firebaseio.com/[PATH].json -> update existing data with json format
#
# DELETE request: curl -X DELETE https://[PROJECT_ID].firebaseio.com/[PATH].json -> delete this entry
#
# Reason for choosing Firebase : it is free! And it does not take much time to learn the basics
#
def craft_firebase_command path, method = 0, data = ""
  # use JSON to generate content (either JSON or normal data types)
  data = JSON.generate(data).gsub /\"/, '\\"'

  # maximum 5 seconds before this command terminates
  connection_timeout  = '--connect-timeout 5'
  additional_options  = '-s'
  inside_thread       = true

  # all possible options for curl
  options = case method.to_s.upcase
            when /1|PUT/
              "-X PUT -d \"#{data}\""
            when /2|POST/
              "-X POST -d \"#{data}\""
            when /3|PATCH/
              "-X PATCH -d \"#{data}\""
            when /4|DELETE/
              "-X DELETE"
            else
              inside_thread = false
              ""
            end

  if inside_thread
    Thread.start {
      result = `curl #{options} https://#{PROJECT_NAME}.firebaseio.com/#{path} #{connection_timeout} #{additional_options}`
      log_everything("Method: #{method} to path \"#{path}\" inside another thread")
      log_everything("Result of the call: #{result}")

      # if one is interested to see the result of other method than GET, can do it through .fetch(:result)
      # however, one must wait for this thread to go to sleep or is dead in order to get it
      Thread.current[:result] = result
    }
  else
    result = `curl #{options} https://#{PROJECT_NAME}.firebaseio.com/#{path} #{connection_timeout} #{additional_options}`
    log_everything("Method: #{method} to path #{path} inside main thread")
    log_everything("Result of the call: #{result}")

    # because data from firebase server is under JSON for normal data types, it is safe to call JSON.parse function in any situation
    JSON.parse(result)
  end
end



# Theory : put available game sessions into an array (or a queue)
# so that other users can find available games and get that game_id for joining and playing
#
# using firebase command to get current queue in the server
def get_current_queue
  log_everything("Get current queue")
  craft_firebase_command("minesweeper/queue.json")
end

# update current queue inside the server
def update_current_queue new_queue
  log_everything("Update current queue")
  log_everything("New queue: \"#{new_queue.to_s}\"")
  craft_firebase_command("minesweeper/queue.json", "PUT", new_queue)
end

# register new game to the queue and then push it to the server
def register_game_to_queue game_id
  log_everything("Register game to current queue")
  # get current queue (an empty array if there is nothing present)
  current_queue = get_current_queue || []
  current_queue << game_id

  # update the queue
  update_current_queue(current_queue)
end

# delete game id in the queue that communication is no longer received from host's side
def delete_game_id_in_queue game_id, queue = nil
  current_queue = queue || craft_firebase_command("minesweeper/queue.json")

  # getting new queue to update
  new_queue = current_queue&.reject { |queue_game_id|
    # reject chosen game
    game_id == queue_game_id
  }

  # update queue on server
  update_current_queue(new_queue)
end

# global game_id in the server serves as unique game id for multiple games take place
def get_next_game_id
  log_everything("Get next game id")
  # get current registered game id
  retrieved_game_id_number = craft_firebase_command("minesweeper/game_id.json").to_i
  game_id = retrieved_game_id_number + 1

  # update game id (increment by 1)
  craft_firebase_command("minesweeper/game_id.json", "PUT", game_id)

  # return current game id
  game_id
end


# ###################### Two ways of entering multiplayer : Create and join ######################
# establish new game session and return new game_id
def establish_game_session game_data, when_game_id_received
  # get next game id
  game_id = get_next_game_id

  # call the procedure when game id is received
  when_game_id_received.call(game_id)

  # register new game id into queue for other user to search
  register_game_to_queue(game_id)

  # write initial data of the game to the server
  flags = game_data["bombs"] || 10
  width = game_data["board_width"] || 10
  height = game_data["board_height"] || 10
  game_data = {
    # default with easy mode
    "board_width"   => width,
    "board_height"  => height,
    "bombs"         => flags,
    "game_id"       => game_id
  }

  # initialize new session
  new_session = {
    "host" => initialize_board_view(width, height),
    "opponent" => initialize_board_view(width, height),
    "data" => game_data,
    "who_win" => -2
  }

  # write to server new game data
  craft_firebase_command("minesweeper/game#{game_id}.json", "PUT", new_session)

  # return new game data
  game_data
end

# join into a random available game inside the server,
# which could be called as blind-picking opponent
# if this function return -1 then there is no game available now; else that is the game_id to play with other player
def join_available_game_session when_game_id_received
  current_queue = get_current_queue
  return -1 if current_queue == nil
  
  # return game_id for user to join the game
  queue_size = current_queue.size
  game_id = case queue_size
            when 0
              log_everything("There is currently no game available! Please try again later or you can create new game here")
              -1
            when 1
              current_queue.pop
            else
              current_queue[rand(queue_size)]
            end

  # don't go further if there is no game available
  return game_id if game_id == -1

  # else call the procedure when game id received
  when_game_id_received.call(game_id)

  # delete the chosen game id in the queue in the server
  delete_game_id_in_queue(game_id, current_queue)

  # set game state to playing
  # prevent unsynchronised data confirmation
  current_game_state = craft_firebase_command("minesweeper/game#{game_id}/who_win.json")
  craft_firebase_command("minesweeper/game#{game_id}/who_win.json", "PUT", -1) if current_game_state.to_i == -2

  # an empty game can not be shown and should be deleted instead
  if current_game_state.to_i == -3
    finish_game_session(game_id)
    return -1
  end

  # return current game data
  craft_firebase_command("minesweeper/game#{game_id}/data.json", "GET")
end

# finish and clean up a game instead of leaving as it be inside the server,
# which can flood server with unnecessary datas
def finish_game_session game_id
  craft_firebase_command("minesweeper/game#{game_id}.json", "DELETE")

  # also, delete game id so that the queue will not contain unplayable game
  delete_game_id_in_queue(game_id)
end

# ############################### Communication ###############################
# communicate to each other as either players' perspective
#
# WARNING : this function can only be called at least 500ms/request as there will be so many requests to the server that would crash.
# The recommended default requesting rate is 1s/request
def communicate_to_server as_host, game_id, game_data
  result = {}

  # deciding sides depending on as_host
  visual_player = as_host ? "opponent"  : "host"
  main_player   = as_host ? "host"      : "opponent"

  # get current game state
  current_game_state = craft_firebase_command("minesweeper/game#{game_id}/who_win.json")

  # actual game communication is only be verified when both sides are in the playing state
  if current_game_state == -1
    # retrieve opponent's data for visual
    other_player_board_view = craft_firebase_command("minesweeper/game#{game_id}/#{visual_player}.json")

    # start updating other player's data for next Gosu tick
    # update board view (logical board view - only thing to be changed here)
    result[:board_view] = other_player_board_view
    
    # write current player's new data to server
    craft_firebase_command("minesweeper/game#{game_id}/#{main_player}.json", "PUT", game_data)
  end

  # return who is winning (must always be an Integer, else it is a falsy case)
  result[:game_state] = Integer(current_game_state) rescue false

  result
end