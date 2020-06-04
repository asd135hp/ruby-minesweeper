require_relative 'components.rb'

# ##################################### File handler #####################################
# set default values for values from reading map file
def default_num_value from_string, to_f = false
  if from_string == nil
    return nil
  end

  num = to_f ? from_string.to_f : from_string.to_i
  return num == -1? nil : num
end

def default_hex_value from_string
  if from_string == nil
    return nil
  end

  value = from_string.to_i(16)
  return value == -1 ? nil : value
end

def default_string_value from_string
  case from_string
  when 'nil'
    nil
  when 'fd'
    DEFAULT_FONT
  else
    from_string
  end
end

# assign function name and function arguments string to the hash's reference
def get_function_from_line line, ref_option_hash
  # if it is a funciton define it first
  if line.match(/->/) != nil
    # when string is prefixed with ->, it recommends an action for the button
    # save the value rather than declaring lambda function here
    # due to colliding variable references that lambda function is not a good idea
    # also, storing function's arguments for later call for less code being written
    function_list = line[2..].strip.split

    # just a debug, telling which info that this function gets
    debug(lambda { puts function_list.to_s })

    # accordingly assign to slot of function name and function arguments in order to call it later
    ref_option_hash[:function_name] = function_list[0]
    ref_option_hash[:function_args] = function_list[1..]
    return true
  end
  
  return false
end

# only return true if it is the end of stage definition
def read_string_to_conclude_stage str, args, stage
  # when there is only one value then it must be a string
  case str
  when 'end'
    return true
  when 'flexible'
    # defines a flexible button
    stage << define_flexible_button(args[0], args[1], args[4], args[5])
  when 'immutable'
    # defines an immutable button
    stage << define_immutable_button(args[0], args[1], args[2], args[3], args[4], args[5])
  when 'image'
    # indicates an image sprite
    # text is image's resource
    # anything else is as expected
    stage << define_image_resource(args[4], args[0], args[1], args[2], args[3], args[5])
  else
    # else it will be button's text
    args[4] = str
  end

  return false
end


## Read from map file into components to draw into Gosu window
def read_from_map_file
  stages = Array.new

  # safe check first
  if File.exist?("#{RESOURCE_DIR}/map.txt")
    File.open("#{RESOURCE_DIR}/map.txt", 'r') { |file|
      # argument list :
      # [x <Type:Float>, y <Type:Float>, width <Type:Float>, height <Type:Float>, text <Type:String>, options <Type:Hash>]
      argument_list = [0, 0, 0, 0, '', {}]

      # a single stage of UI
      stage = Array.new

      # start converting map file into actual UI map full of button in each stages array
      while line = file.gets
        # ignore comments or empty strings
        next if line.strip.length == 0 or line[0..2] == ';;;'

        # get function from given line
        next if get_function_from_line(line, argument_list[5])

        # no splitting when it is a raw string (indicated by '!')
        values = line[0] == '!' ? [line[1..]] : line.split

        case values.length
        when 1
          if read_string_to_conclude_stage(values[0], argument_list, stage)
            # indicates the end of UI stage
            stages << stage
            stage = Array.new
          end
        when 2
          # two arguments in a line (all convert to float) representing x, y
          argument_list[0..1] = *(values.map { |val| val.to_f })
        when 4
          # four arguments in a line (all convert to float) representing x, y, width_scale, height_scale
          argument_list[0..3] = *(values.map { |val| val.to_f })
        else
          # list of arguments into a hash
          i = 0
          argument_list[5] = {
            :font_size        => default_num_value(values[i]),
            :horizontal_align => default_num_value(values[i += 1], true),
            :vertical_align   => default_num_value(values[i += 1], true),
            :background_color => default_hex_value(values[i += 1]),
            :color            => default_hex_value(values[i += 1]),
            :border_color     => default_hex_value(values[i += 1]),
            :border_thickness => default_num_value(values[i += 1]),
            :font             => default_string_value(values[i += 1]),
            :padding_top      => default_num_value(values[i += 1]),
            :padding_left     => default_num_value(values[i += 1])
          }
        end
      end
      
      # if there is no 'end' flag at EOF, automatically clean it
      stages << stage if stage.length > 0
      stage = nil
    }
  end

  stages
end

############################################# FILE HANDLER #############################################
# Those functions support the use of mapping in separate file for better and easier UI design          #
########################################################################################################

# ##################################### File handler #####################################
# set default values for values from reading map file
def default_num_value from_string, to_f = false
  if from_string == nil
    return nil
  end

  num = to_f ? from_string.to_f : from_string.to_i
  return num == -1? nil : num
end

def default_hex_value from_string
  if from_string == nil
    return nil
  end

  value = from_string.to_i(16)
  return value == -1 ? nil : value
end

def default_string_value from_string
  case from_string
  when 'nil'
    nil
  when 'fd'
    DEFAULT_FONT
  else
    from_string
  end
end

# assign function name and function arguments string to the hash's reference
def get_function_from_line line, ref_option_hash
  # if it is a funciton define it first
  if line.match(/->/) != nil
    # when string is prefixed with ->, it recommends an action for the button
    # save the value rather than declaring lambda function here
    # due to colliding variable references from lambda function is not a good idea
    # also, storing function's arguments for later call so that less code will be written
    function_list = line[2..].strip.split

    # just a debug, telling which info that this function gets
    log_everything(function_list.to_s, true)

    # accordingly assign to slot of function name and function arguments in order to call it later
    ref_option_hash[:function_name] = function_list[0]
    ref_option_hash[:function_args] = function_list[1..]
    return true
  end
  
  return false
end

# only return true if it is the end of stage definition
def read_string_to_conclude_stage str, args, stage
  # when there is only one value then it must be a string
  case str
  when 'end'
    return true
  when 'flexible'
    # defines a flexible button
    stage << define_flexible_button(args.x, args.y, args.text, args.options)
  when 'immutable'
    # defines an immutable button
    stage << define_immutable_button(args.x, args.y, args.width, args.height, args.text, args.options)
  when 'image'
    # indicates an image sprite
    # text is image's resource
    # anything else is as expected
    stage << define_image_resource(args.text, args.x, args.y, args.width, args.height, args.options)
  else
    # else it will be button's text
    args.text = str
  end

  return false
end


## Read from map file into components to draw into Gosu window
def read_from_map_file
  stages = Array.new

  # safe check first
  if File.exist?("#{RESOURCE_DIR}/map.txt")
    File.open("#{RESOURCE_DIR}/map.txt", 'r') { |file|
      # argument list :
      # [x <Type:Float>, y <Type:Float>, width <Type:Float>, height <Type:Float>, text <Type:String>, options <Type:Hash>]
      argument_list = initialize_argument_list

      # a single stage of UI
      stage = Array.new

      # start converting map file into actual UI map full of button in each stages array
      while line = file.gets
        # ignore comments or empty strings
        next if line.strip.length == 0 or line[0..2] == ';;;'

        # get function from given line
        next if get_function_from_line(line, argument_list.options)

        # no splitting when it is a raw string (indicated by '!')
        values = line[0] == '!' ? [line[1..]] : line.split

        case values.length
        when 1
          if read_string_to_conclude_stage(values[0], argument_list, stage)
            # indicates the end of UI stage
            stages << stage
            stage = Array.new
          end
        when 2
          # two arguments in a line (all convert to float) representing x, y
          argument_list.x, argument_list.y = *(values.map { |val| val.to_f })
        when 4
          # four arguments in a line (all convert to float) representing x, y, width_scale, height_scale
          argument_list.x, argument_list.y, argument_list.width, argument_list.height = *(values.map { |val| val.to_f })
        else
          # list of arguments into a hash
          i = 0
          argument_list.options = {
            :font_size        => default_num_value(values[i]),
            :horizontal_align => default_num_value(values[i += 1], true),
            :vertical_align   => default_num_value(values[i += 1], true),
            :background_color => default_hex_value(values[i += 1]),
            :color            => default_hex_value(values[i += 1]),
            :border_color     => default_hex_value(values[i += 1]),
            :border_thickness => default_num_value(values[i += 1]),
            :font             => default_string_value(values[i += 1]),
            :padding_top      => default_num_value(values[i += 1]),
            :padding_left     => default_num_value(values[i += 1])
          }
        end
      end
      
      # if there is no 'end' flag at EOF, automatically clean it
      stages << stage if stage.length > 0
      stage = nil
    }
  end

  stages
end