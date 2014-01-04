Escape    = "\e"
Enter     = "\n"
UpArrow   = "8"
DownArrow = "2"

class IO
  # Read as much as possible without blocking for more than 5ms per read.
  def read_available_nonblock
    buffer = ""
    begin
      while true
        addition = self.read_nonblock(8192)
        Kernel::print addition
        buffer << addition
      end
    rescue IO::WaitReadable => err
      retry if IO.select([self], nil, nil, 0.005)
      raise err if buffer.empty?
    end
    buffer
  end

  # The same as read_available_nonblock, but block until there is data.
  def read_available
    IO.select([self])
    self.read_available_nonblock
  end
end

def write_figure index, data
  first = true
  related_entities_seen = false
  new_line = false
  header_printed = false

  open("fig#{index}.html", "w") do |f|
    f.puts "<p>"
    data.force_encoding(Encoding::UTF_8).gsub(/\e\[[0-9]*;[23]H/, "\n").gsub(/\e\[[0-9;]*./, '').gsub(/\e./, '').gsub(/(\u0008|\u000f|\u2022|\u2502|\u2191|\u2193)/, '').each_line do |line|
      line = line.strip

      if first and not line.empty?
        first = false
        next
      end

      if line == "Related Entities"
        related_entities_seen = true
        new_line = true
      end

      if related_entities_seen
        if line.empty?
          new_line = true unless header_printed
        elsif new_line
          if line == "Related Entities"
            f.puts "</p>"
          else
            f.puts "</ul>"
          end
          f.puts
          f.puts "<h2>" + line + "</h2>"
          f.puts "<ul>"
          header_printed = true
          new_line = false
        else
          header_printed = false
          f.puts "<li>" + line + "</li>"
        end
      else
        if line.start_with? 'In '
          f.puts "</p>\n<p>"
        end
        f.puts line
      end
    end
    f.puts "</ul>"
  end
end

figure_index = 1

IO.popen('../df_linux/df', 'r+') do |df|
  df.read_available # ignore "reading bindings"
  text = df.read_available[/\e\[37m\e\[40m(\w+ Playing)\e/, 1] until text
  case text
  when 'Continue Playing'
    df.write DownArrow
    df.read_available
    df.write Enter
  when 'Start Playing'
    df.write Enter
  else
    df.write UpArrow
    df.read_available
    df.write Enter
    df.read_available
    raise Exception, text.inspect
  end

  df.read_available # wait for menu to load, then discard it
  # Select legends mode
  df.write UpArrow
  df.read_available
  df.write Enter

  # wait for legends mode to load
  text = df.read_available until text['Historical events left to discover:']

  # Select "historical figures"
  df.write Enter

  original_listing = df.read_available
  text = nil

  while text != original_listing
    df.write Enter
    figure = ""
    catch :break do
      while true
        begin
          IO.select([df], nil, nil, 1)
          figure << df.read_available_nonblock
          df.write DownArrow
        rescue IO::WaitReadable
          throw :break
        end
      end
    end

    write_figure figure_index, figure
    figure_index += 1

    df.write Escape
    df.read_available
    df.write DownArrow
    text = df.read_available
  end

  df.write Escape
  df.read_available
  df.write Escape
  df.read_available
  df.write UpArrow
  df.read_available
  df.write Enter
  df.read_available
end

p figure
