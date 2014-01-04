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

class String
  def paramcase
    self.downcase.strip.gsub(/\s+/, '-')
  end
end

def write_figure data
  $fault_data = data[0..-1]

  first = true
  related_entities_seen = false
  first_related_entity = false
  header_printed = false
  first_text_printed = false
  section = nil
  first_name = nil

  data.force_encoding Encoding::UTF_8
  data.gsub! /\e\[[0-9]*;[23]H/, "\n"
  data.gsub! /\e\[[0-9;]*./, ''
  data.gsub! /\e./, ''
  data.gsub! /(\u0008|\u000f|\u2022|\u2502|\u2191|\u2193)/, ''

  open "fig-#{data[/^(.*?)\s+was\s+a\s+/, 1].paramcase}.html", "w" do |f|
    f.puts "<p>"
    data.each_line do |line|
      line = line.strip

      if first and not line.empty?
        first = false
        next
      end

      if line[/\ARelated\b|\bKills?\z/] and !related_entities_seen
        related_entities_seen = true
        first_related_entity = true
      end

      if related_entities_seen
        if line[/\ARelated\b|\bKills?\z/]
          if first_related_entity
            f.puts "</p>"
            first_related_entity = false
          else
            f.puts "</ul>"
          end
          f.puts
          f.puts "<h2>" + line + "</h2>"
          f.puts "<ul>"
          section = line
          header_printed = true
        elsif !line.empty?
          header_printed = false
          case section
          when /\ARelated Entities\z/
            line.gsub! /\A(.*?)\s+\(/ do
              "<a href=\"ent-#{$1.paramcase}.html\">#{$1}</a> ("
            end
          when /(?<! Other) Kills?\z/
            line.gsub! /\A(.*?)(\s+the\s+[a-z])/ do
              "<a href=\"fig-#{$1.paramcase}.html\">#{$1}</a>#{$2}"
            end
          when /(?<! Notable) Kills?\z/
            line.gsub! /\s+in\s+([A-Z].*)\z/ do
              " in <a href=\"site-#{$1.paramcase}.html\">#{$1}</a>"
            end
          end
          f.puts "<li>" + line + "</li>"
        end
      else
        if line.start_with? 'In '
          first_text_printed = true
          f.puts "</p>"
          f.puts
          f.puts "<p>"

          line.gsub! /#{first_name}\s+(struck\s+down|attacked)(\s+the\s+[^A-Z]+)([A-Z].*?)(\s+in\s+([A-Z].*))?\./ do
            in_site = ""
            in_site = " in <a href=\"site-#{$5.paramcase}.html\">#{$5}</a>" if $5
            "#{first_name} #{$1}#{$2}<a href=\"fig-#{$3.paramcase}.html\">#{$3}</a>#{in_site}."
          end
        else
          line.gsub! /\A(.*?)\s+was\s+a\s+/ do
            first_name = $1[/\A\S+/]
            "<strong>#{$1}</strong> was a "
          end
        end
        f.puts line unless line.empty?
      end
    end
    if related_entities_seen
      f.puts "</ul>"
    else
      f.puts "</p>"
    end
  end
  $fault_data = nil
end

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

  begin
    # wait for legends mode to load
    text = df.read_available until text['Historical events left to discover:']

    # Select "historical figures"
    df.write Enter

    begin
      original_listing = df.read_available
      text = nil

      while text != original_listing
        begin
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

          write_figure figure

        ensure
          df.write Escape
          df.read_available
        end
        df.write DownArrow
        text = df.read_available
      end

    ensure
      df.write Escape
      df.read_available
    end
  ensure
    df.write Escape
    df.read_available
    df.write UpArrow
    df.read_available
    df.write Enter
    df.read_available

    p $fault_data if $fault_data
  end
end
