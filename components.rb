
################################################### COMPONENTS ###################################################
# Components for drawing out to the screen
##################################################################################################################
# ################################### DEFINING COMPONENTS ###################################
# Generic - alignment
def component_alignment horizontal_align, vertical_align, window_width, window_height, board_width, board_height
  x = y = nil

  if horizontal_align != nil and horizontal_align >= 0 and horizontal_align <= 1
    x = (window_width - board_width) * horizontal_align
  end
  if vertical_align != nil and vertical_align >= 0 and vertical_align <= 1
    y = (window_height - board_height) * vertical_align
  end

  { :x => x, :y => y }
end
# Generic - define lambda function for given options
def get_function function_name, function_args
  # declare lambda function
  lambda { |ui, player, database, current_running_threads|
    # splat function arguments here to pass pre-defined arguments to a specific function
    # transform from OOP to structural: pre-defined arguments go first, all compulsory arguments go after
    arguments = [*function_args, ui, player, database, current_running_threads]
    send(function_name, *arguments) if function_name != nil
  }
end

# UI components
# options<Type:Hash> -> { :font_size, :font }
def define_text_image text, options = {}
  Gosu::Image.from_text(text.to_s, options[:font_size] || 16, { :font => options[:font] || DEFAULT_FONT })
end

# change button's text
def change_button_text texture, new_value
  log_everything("Change #{texture.type} ##{texture.unique_id}'s text to \"#{new_value.to_s}\"")
  texture.text = define_text_image(new_value, { :font => texture.font, :font_size => texture.font_size })
end


########################### BUTTON ###########################
# flexibleness refers to button's resizability
#
# in order to change text, change hash's value of :text to the procedure define_text_image's value
#
# x <Type:Integer>, y <Type:Integer>, width <Type:Integer>, height <Type:Integer>, text <Type:String>
#
# options <Type:Hash> -> {
#   :font_size, :font, :horizontal_align, :vertical_align, :padding_top, :padding_left, :border_thickness
#   :background_color, :color, :border_color,
#   :window_width, :window_height
#   :function_name : To call function name from current object,
#   :function_args
# }
def define_flexible_button x, y, text, options = {}
  @text = define_text_image(text, { :font_size => options[:font_size], :font => options[:font] })

  # standard values
  window_width      = options[:window_width] || WINDOW_WIDTH
  window_height     = options[:window_height] || WINDOW_HEIGHT
  text_padding_top  = options[:padding_top] || 10
  text_padding_left = options[:padding_left] || 20
  width             = @text.width + text_padding_left * 2
  height            = @text.height + text_padding_top * 2

  # alignment (neglect x and y values)
  align = component_alignment(options[:horizontal_align], options[:vertical_align], window_width, window_height, width, height)
  x = align[:x] || x
  y = align[:y] || y

  options[:debug_text] = text
  initialize_button("flexible-button", x, y, width, height, @text, options)
end

# immutable refers to static width and height
#
# overflowing text will continue to overflow without clipping
#
# in order to change text, change hash's value of :text to the procedure define_text_image's value
#
# x <Type:Integer>, y <Type:Integer>, width_scale <Type:Float>, height_scale <Type:Float>, text <Type:String>
#
# options <Type:Hash> -> {
#   :font_size, :font, :horizontal_align, :vertical_align, :background_color, :color, :border_color, :border_thickness, :function_name,
#   :function_args, :window_width, :window_height
# }
def define_immutable_button x, y, width_scale, height_scale, text, options = {}
  @text = define_text_image(text, { :font_size => options[:font_size], :font => options[:font] })

  # standard values
  window_width      = options[:window_width] || WINDOW_WIDTH
  window_height     = options[:window_height] || WINDOW_HEIGHT
  width             = window_width * width_scale
  height            = window_height * height_scale

  # set padding to options set
  options[:padding_top]  = (height - @text.height) / 2
  options[:padding_left] = (width - @text.width) / 2

  # alignment (neglect x and y values)
  align = component_alignment(options[:horizontal_align], options[:vertical_align], window_width, window_height, width, height)
  x = align[:x] || x
  y = align[:y] || y

  options[:debug_text] = text
  initialize_button("immutable-button", x, y, width, height, @text, options)
end

# draw image from source (just file name, not the whole path)
#
# options<Type:Hash> -> { :z_index, :window_width, :window_height, :horizontal_align, :vertical_align }
def define_image_resource src, x, y, width, height, options = {}
  image   = Gosu::Image.new("#{RESOURCE_DIR}/#{src.strip}")
  z_index = case options[:z_index]
            when 'background'
              ZOrder::BACKGROUND
            when 'game'
              ZOrder::GAME
            else
              ZOrder::UI
            end

  window_width = options[:window_width] || WINDOW_WIDTH
  window_height = options[:window_height] || WINDOW_HEIGHT
  align = component_alignment(options[:horizontal_align], options[:vertical_align], window_width, window_height, width, height)
  x = align[:x] || x
  y = align[:y] || y

  initialize_image_resource(image, x, y, width, height, z_index)
end

# ######################################### DRAW #########################################
# draw button-like texture
def draw_button_like_texture texture
  # pre-define reusing values (for less typing)
  x                 = texture.x
  y                 = texture.y
  width             = texture.width
  height            = texture.height
  border_thickness  = texture.border_thickness

  # draw button and its border
  Gosu::draw_rect(
    x - border_thickness,
    y - border_thickness,
    width + border_thickness * 2,
    height + border_thickness * 2,
    texture.border_color,
    ZOrder::BORDER,
    :default
  )
  Gosu::draw_rect(x, y, width, height, texture.background_color, ZOrder::UI, mode = :default)

  # draw inside text
  texture.text.draw(x + texture.text_padding_left, y + texture.text_padding_top, ZOrder::TEXT, 1, 1, texture.color, :default)
end

# draw image from source
def draw_image_resource resource
  resource.image.draw(resource.x, resource.y, resource.z_index || ZOrder::UI, resource.scale_x, resource.scale_y)
end

# generic drawing
def draw_texture texture
  case texture.type
  when /button/
    draw_button_like_texture(texture)
  when "image"
    draw_image_resource(texture)
  end
end

# button<Type : Hash>, mouse_x<Type:Integer>, mouse_y<Type:Integer>
def is_mouse_inside_button? button, mouse_x, mouse_y
  x         = button.x || -1
  y         = button.y || -1
  width     = button.width || 0
  height    = button.height || 0
  thickness = button.border_thickness || 0

  # should also include border when checking mouse's position
  (mouse_x >= x - thickness and mouse_x < x + width + thickness) and (mouse_y >= y - thickness and mouse_y < y + height + thickness)
end