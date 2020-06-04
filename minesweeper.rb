require 'gosu'

# throws exceptions to current thread even different thread has that exception
Thread.abort_on_exception = true
Thread.report_on_exception = false

# define contants
WINDOW_WIDTH = 1100
WINDOW_HEIGHT = 650
DEFAULT_FONT = 'Arial'

# constants in multiplayer part
VIEW_BOARD_MARGIN = 20      # other player's board margin from border separation
VIEW_SQUARE_SIZE = 10       # other player's squares size
VIEW_BORDER_SEPARATION = 2  # separation between two board views

# screen is static instead of dynamic due to errors encountered
OPPONENT_VIEW_WIDTH = 250

# flags for identifying many in-game situations
FLAGS = {
  :is_win                 => false,
  :is_host                => false,
  :info_not_set           => true,
  :is_multiplayer         => false,
  :is_game_started        => false,
  :initial_data_updated   => false,
  :is_finish_message_set  => false,
  :time_from_last_update  => 0,
}
# visual data for multiplayer's opponent side
OPPONENT_VISUAL_DATA = {
  :square_size  => 10,
  :margins      => {}
}
# this is for stage 7 - when host is customizing the game
MODIFIABLE_MULTIPLAYER_DATA = {
  "board_width"         => 10,
  "board_width_limit"   => [5, 40],
  "board_height"        => 10,
  "board_height_limit"  => [5, 20],
  "bombs"               => 10,
  "bombs_limit"         => [10, 10]
}
# directory for resource in physical memory
RESOURCE_DIR = 'resources'

# data collisions are proven to be too much => predefined constants for some stages
module Stage
  MAIN_MENU, CUSTOM, GAME_PLAY, END_MESSAGE, SKIP_THIS, MULTIPLAYER, MULTIPLAYER_DATA, MULTIPLAYER_PLAY = *0..7
end

module ZOrder
  BACKGROUND, GAME, BORDER, UI, TEXT = *-1..3
end

module SquareType
  FLAG, BOMB, COVER, ZERO, ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT = *(["flag", "bomb", "cover", *0..8].map { |value| 
    Gosu::Image.new("#{RESOURCE_DIR}/#{value}.png")
  })
end




class Button
  attr_accessor :type, :unique_id, :x, :y, :width, :height, :text, :font, :font_size, :text_padding_top, :text_padding_left,
    :background_color, :color, :border_color, :border_thickness, :action
end

class ImageResource
  attr_accessor :type, :x, :y, :scale_x, :scale_y, :z_index, :image
end

# properties to be changed later so initialization does not take any arguments
class ArgumentList
  attr_accessor :x, :y, :width, :height, :text, :options
end


# ui representation
class UIInPlayingMode
  attr_accessor :timer_texture, :flags_texture
end
class UI
  attr_accessor :stages, :playing_mode, :loading_screen, :level
end


# contains all single player data for both modes
class SinglePlayerData
  attr_accessor :board, :board_view, :board_width, :board_height, :square_size, :bombs, :flags, :bombs_positions, :timer,
    :margins, :level
end

# proportional representation of the firebase database after each curl calls
class Database
  attr_accessor :opponent_board_view, :game_id
end

require_relative 'reuse_function.rb'
require_relative 'file_handler.rb'
require_relative 'game_init.rb'
require_relative 'multiplayer_mode.rb'
require_relative 'game_helpers.rb'
require_relative 'window_functions.rb'

# start the initial thread 
class Window < Gosu::Window
  attr_accessor :ui, :player, :database, :current_running_threads
  def initialize
    super WINDOW_WIDTH, WINDOW_HEIGHT
    self.caption = 'Minesweeper'
    # update per 100ms
    self.update_interval = 100
  end

  def needs_cursor?
    true
  end

  def update
    # get the first thread ran, which contains initial informations for some fields
    init_thread = @current_running_threads[0]

    # procedure when 1 second has passed
    case @ui.level
    when -1
      # only change text when the thread is running
      if init_thread.status
        new_info_text = init_thread.fetch(:new_queue_info, "")

        # change new text image
        change_button_text(@ui.loading_screen[0], new_info_text) if new_info_text != ""
      end
    when 3
      timer_increment(@ui.playing_mode.flags_texture, @ui.playing_mode.timer_texture, @player)
    when 4
      craft_message_after_game(@database.game_id, @ui.stages, @player)
    when 8
      # unless initial data is updated, update data
      unless FLAGS[:initial_data_updated]
        init_flag_num = init_thread.fetch(:init_flag, -1)

        # break if nothing has received
        return if init_flag_num == -1

        log_everything("Initial flag number: #{init_flag_num}")
        change_button_text(@ui.playing_mode.flags_texture, init_flag_num)

        FLAGS[:initial_data_updated] = true
      end

      # fetching opponent's board
      @database.opponent_board_view = @current_running_threads[1].fetch(:opponent_board_view, [])

      timer_increment(@ui.playing_mode.flags_texture, @ui.playing_mode.timer_texture, @player)
    end
  end

  def button_up which_button
    case which_button
    when Gosu::MS_LEFT
      left_mouse_button_action(mouse_x, mouse_y, @ui, @player, @database, @current_running_threads)
    when Gosu::MS_RIGHT
      right_mouse_button_action(@ui.level, @ui.playing_mode.flags_texture, mouse_x, mouse_y, @player, @current_running_threads[1])
    end
  end

  # after multiplayer session, clean everything and reverts them back to the original state!
  # opponent's board, modifiable_multiplayer_data
  def draw
    Gosu.draw_rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0xff_000000, ZOrder::BACKGROUND)
    
    # draw all possible components in that specific UI stage
    if @ui.level > 0
      @ui.stages[@ui.level - 1]&.each { |texture|
        draw_texture(texture)
      }
    else
      # it will becomes loading screen instead if @ui.level - 1 yields negative value
      @ui.loading_screen.each { |texture|
        # draw everything
        draw_texture(texture)
      }
    end

    # only play is different from the rest
    draw_board_view(@player.board_view, @player.margins, @player.square_size) if @ui.level == 3 or @ui.level == 8

    # multiplayer drawing part
    if @ui.level == 8
      # draw a line to separate main and opponent's board in multiplayer mode
      Gosu.draw_rect(WINDOW_WIDTH - OPPONENT_VIEW_WIDTH, 0, VIEW_BORDER_SEPARATION, WINDOW_HEIGHT, 0xff_ffffff)

      # draw a small board at right-most area, which is opponent's board (and is also flipped 90 degrees)
      data = OPPONENT_VISUAL_DATA
      draw_board_view(@database.opponent_board_view, data[:margins], data[:square_size], true)
    end
  end

  def close
    upon_closing(@database.game_id, @ui.level, @current_running_threads)

    # delete successful log file if user can still close this window
    delete_log_file()

    # forcefully close window because it needs user to click twice to close it
    self.close!
  end
end

begin
  log_everything("Notice: If this program spawns more than 20 log files, you can safely delete about 15-18 of them.")
  window = Window.new
  initialize_window(window)
  window.show
rescue => e
  # wait until the thread finishes execution
  log_everything("Exception raised: #{e.inspect} with message: #{e.message}")
  log_everything("Traceback: #{e.backtrace_locations.join("\n")}")
  upon_closing(window.database.game_id, window.ui.level, window.current_running_threads)
end