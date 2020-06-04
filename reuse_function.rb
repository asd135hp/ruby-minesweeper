require 'date'

################################ INITIALIZATION FOR OBJECTS ################################
# log every kind of message
FILE_TIMESTAMP = DateTime.now.to_time.to_i
$log_file_open = false
def log_everything msg, is_debug = false
  Thread.start{
    # dunno what is a better way but this will make text in file format more beautifully
    # wait until the file is available to write
    # and yes, I used global variable
    while $log_file_open
    end

    if !is_debug || ARGV.length > 1
      $log_file_open = true
      File.open("logs/log-#{FILE_TIMESTAMP}.txt", "a+"){ |file|
        file.puts "[#{DateTime.now}] #{msg}" rescue nil
        $log_file_open = false
      } rescue nil
    end
  }.join
end

# delete successful log files so that it does not flood user's hard drive with garbage logs
def delete_log_file
  # wait until the file is opened to read/write
  while $log_file_open
  end
 
  File.delete("logs/log-#{FILE_TIMESTAMP}.txt")
end

# initialize new button
def initialize_button type, x, y, width, height, text, options = {}
  button = Button.new

  # hoping that this will not collide (debugging & logging purpose only)
  button.unique_id          = rand(100000)
  button.type               = type
  button.x                  = x
  button.y                  = y
  button.width              = width
  button.height             = height
  button.font               = options[:font]
  button.font_size          = options[:font_size]
  button.text_padding_top   = options[:padding_top] || 10
  button.text_padding_left  = options[:padding_left] || 20
  button.background_color   = options[:background_color] || 0xff_000000
  button.color              = options[:color] || 0xff_ffffff
  button.border_color       = options[:border_color] || 0xff_ffffff
  button.border_thickness   = options[:border_thickness] || 1
  button.action             = get_function(options[:function_name], options[:function_args] || [])
  button.text               = text

  log_everything("Created button of type #{type} with id of #{button.unique_id}, assigned with text: #{options[:debug_text]}", true)

  button
end

# initialize new image resource
def initialize_image_resource image, x, y, width, height, z_index
  resource          = ImageResource.new
  resource.x        =  x
  resource.y        =  y
  resource.type     =  "image"
  resource.image    =  image
  resource.z_index  =  z_index
  resource.scale_x  =  width / image.width
  resource.scale_y  =  height / image.height

  resource
end

# initialize new argument list
def initialize_argument_list
  args = ArgumentList.new
  args.x = args.y = args.width = args.height = 0
  args.text = ''
  args.options = {}

  args
end

# initialize ui datas
def initialize_ui stages, loading_screen
  uis = UI.new
  uis.level          = 1
  uis.stages         = stages
  uis.playing_mode   = UIInPlayingMode.new
  uis.loading_screen = loading_screen

  uis
end

# ################################ REUSABLE FUNCTIONS #################################
# get square image according to provided square's value
def get_square_image value
  case value
  when 'c'
    SquareType::COVER
  when 'f'
    SquareType::FLAG
  when -1
    SquareType::BOMB
  when 0
    SquareType::ZERO
  when 1
    SquareType::ONE
  when 2
    SquareType::TWO
  when 3
    SquareType::THREE
  when 4
    SquareType::FOUR
  when 5
    SquareType::FIVE
  when 6
    SquareType::SIX
  when 7
    SquareType::SEVEN
  when 8
    SquareType::EIGHT
  end
end

# time converter
def time_padding value
  value < 10 ? "0#{value}" : value
end
def time_converter seconds
  hours   = seconds / 3600
  minutes = (seconds - hours * 3600) / 60
  seconds = seconds - hours * 3600 - minutes * 60
  hours > 0 ?
    "#{time_padding(hours)}:#{time_padding(minutes)}:#{time_padding(seconds)}" :
    "#{time_padding(minutes)}:#{time_padding(seconds)}"
end


###################### MULTI-THREADING PROBLEM ######################
# because of the need for non-coliiding threads in order for game's network to work properly (not blocking each other's frame)
# this function is born to ease the need for data
# could be inefficient but the work is done
def get_multithread_data thread_arr, parent_thread = nil
  resultant_fiber = {}

  thread_arr.each { |current_thread|
    current_thread.keys.each { |key|
      # if parent_thread is provided then merge data with that thread instead
      if parent_thread
        parent_thread[key] = current_thread[key]
      else
        resultant_fiber[key] = current_thread[key]
      end
    }

    # if current thread's status is stopped or anything else than running then remove that thread from list
    thread_arr.reject { |thread|
      thread[:thread_id] == current_thread[:thread_id]
    } if not current_thread.status  
  }

  resultant_fiber
end

# clean all available threads in the array and clear the array to save some memories (which is not necessary)
def clear_threads thread_pool, clean_array = true
  thread_pool.each{ |thread| thread.exit }
  thread_pool.clear if clean_array
end