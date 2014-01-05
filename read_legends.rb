require 'optparse'

Escape    = "\e"
Enter     = "\n"
UpArrow   = "8"
DownArrow = "2"

options = {skip: 0, section: -1, limit: 1<<30}

Types = {
  figure:    {name: "Figure",    pre: "fig" },
  site:      {name: "Site",      pre: "site"},
  artifact:  {name: "Artifact",  pre: "art"},
  region:    {name: "Region",    pre: "site"},
  entity:    {name: "Entity",    pre: "ent" },
  structure: {name: "Structure", pre: "site"}
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby read_legends.rb [options]"

  opts.on "-s", "--skip N", Integer, "Skip the first N entries" do |n|
    options[:skip] = n
  end

  opts.on "-t", "--section N", Integer, "Only process one section (0:figure/1:site/2:artifact/3:region/4:entity/5:structure)" do |n|
    options[:section] = n
  end

  opts.on "-n", "--limit N", Integer, "Stop after N non-skipped entries" do |n|
    options[:limit] = n
  end
end.parse!

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
    self.gsub(/[?,:"]/, " ").downcase.strip.gsub(/\s+/, "-")
  end
end

def write_page type, data
  $fault_data = data[0..-1]

  first = true
  related_entities_seen = false
  first_related_entity = false
  header_printed = false
  first_text_printed = false
  section = nil
  full_name = nil
  first_name = nil

  data.force_encoding Encoding::UTF_8
  data.gsub! /\e\[[0-9]*;[23]H/, "\n"
  data.gsub! /\e\[[0-9;]*./, " "
  data.gsub! /\e./, " "
  data.gsub! /(\u0008|\u000f|\u2022|\u2502|\u2191|\u2193)/, " "

  $fault_data = [$fault_data, data]

  open "#{Types[type][:pre]}-#{data[/^\s*(.*?)\s+(was\s+(a|the)|could\s+be\s+found\s+in)\s+/, 1].paramcase}.html", "w" do |f|
    f.puts <<-EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>#{data[/^\s*(.*?)\s+(was\s+(a|the)|could\s+be\s+found\s+in)\s+/, 1]} (#{Types[type][:name]})</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<p>
EOF

    line_accum = ""

    link = proc do |prefix, name|
      if name == full_name or name == first_name
        name
      else
        "<a href=\"#{prefix}-#{name.paramcase}.html\">#{name}</a>"
      end
    end

    print_accum = proc do
      line_accum.strip!
      if first_text_printed
        line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+(struck\s+down|shot\s+and\s+killed|attacked|was\s+struck\s+down\s+by|was\s+shot\s+and\s+killed\s+by|devoured|ambushed|fought\s+with|happened\s+upon|confronted)((\s+the\s+[a-z\s\-]+)([A-Z][^\.]*?)|\s+an?\s+[a-z\s\-]+?)(\s+of\s+(The\s+[A-Z][^\.]*?))?(\s+in\s+([A-Z][^\.]*?))?\.(\s+While\s+defeated,\s+the\s+latter\s+escaped\s+unscathed\.)?\z/ do
          of_ent = ""
          of_ent = " of #{link.call "ent", $7}" if $7
          in_site = ""
          in_site = " in #{link.call "site", $9}" if $9
          if $4
            ", #{link.call "fig", $1} #{$2}#{$4}#{link.call "fig", $5}#{of_ent}#{in_site}.#{$10}"
          else
            ", #{link.call "fig", $1}  #{$2}#{$3}#{of_ent}#{in_site}.#{$10}"
          end
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+became\s+(an\s+enemy|the\s+[^\.]*?)\s+of\s+([A-Z][^\.]*?)\.\z/ do
          ", #{link.call "fig", $1} became #{$2} of #{link.call "ent", $3}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+fooled\s+([A-Z][^\.]*?)\s+into\s+believing\s+([a-z]+)\s+was\s+([A-Z][^\.]*?)\.\z/ do
          ", #{link.call "fig", $1} fooled #{link.call "ent", $2} into believing #{$3} was #{link.call "fig", $4}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+attacked\s+([A-Z][^\.]*?)\s+of\s+([A-Z][^\.]*?)\s+at\s+([A-Z][^\.]*?)\.\s+([A-Z][^\.]*?)\s+led\s+the\s+attack\.\z/ do
          ", #{link.call "ent", $1} attacked #{link.call "site", $2} of #{link.call "ent", $3} at #{link.call "site", $4}. #{link.call "fig", $5} led the attack."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+(settled\s+in|began\s+wandering)\s+([A-Z][^\.]*?)\.\z/ do
          ", #{link.call "fig", $1} #{$2} #{link.call "site", $2}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+of\s+([A-Z][^\.]*?)\s+constructed\s+([A-Z][^\.]*?)\s+in\s+([A-Z][^\.]*?)\.\z/ do
          ", #{link.call "ent", $1} of #{link.call "ent", $2} constructed #{link.call "site", $3} in #{link.call "site", $4}."
        end
      else
        line_accum.gsub! /\A(.*?)\s+(was\s+(a|the)|could\s+be\s+found\s+in)\s+/ do
          # Don't lose $1
          full_name = $1
          verb = $2
          first_name = full_name[/\A\S+/]
          "<strong>#{full_name}</strong> #{verb} "
        end
        line_accum.gsub! /\s+in\s+([A-Z][^\.]*?)\.\z/ do
          " in #{link.call "site", $1}."
        end
      end
      f.puts line_accum
    end

    data.each_line do |line|
      line.strip!

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
            print_accum.call
            f.puts "</p>"
            first_related_entity = false
          else
            f.puts "</ul>"
          end
          f.puts
          f.puts "<h2 id=\"#{line[/\ARelated.*\z|((Other|Notable)\s+)?Kills?\z/].paramcase}\">#{line}</h2>"
          f.puts "<ul>"
          section = line
          header_printed = true
        elsif !line.empty?
          header_printed = false
          case section
          when /\ARelated\s+Entities\z/
            line.gsub! /\A(.*?)\s+\(/ do
              "<a href=\"ent-#{$1.paramcase}.html\">#{$1}</a> ("
            end
          when /(?<!\sOther)\s+Kills?\z/
            line.gsub! /\A(.*?)(\s+the\s+[a-z\s+\-])/ do
              "<a href=\"fig-#{$1.paramcase}.html\">#{$1}</a>#{$2}"
            end
          when /(?<!\sNotable)\s+Kills?\z/
            line.gsub! /\s+in\s+([A-Z].*?)\z/ do
              " in <a href=\"site-#{$1.paramcase}.html\">#{$1}</a>"
            end
          end
          f.puts "<li>#{line}</li>"
        end
      else
        if line.start_with? 'In '
          print_accum.call
          line_accum = ""
          first_text_printed = true
          f.puts "</p>"
          f.puts
          f.puts "<p>"
        end
        line_accum << line << " " unless line.empty?
      end
    end
    if related_entities_seen
      f.puts "</ul>"
    else
      f.puts "</p>"
    end
    f.puts "</body>"
    f.puts "</html>"
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

    [:figure, :site, :artifact, :region, nil, :entity, :structure].each do |type|
      unless type
        df.write DownArrow
        df.read_available
        next
      end

      if options[:section] > 0
        options[:section] -= 1
        df.write DownArrow
        df.read_available
        next
      end

      df.write Enter

      begin
        original_listing = df.read_available
        text = nil

        while text != original_listing
          if options[:skip] > 0
            options[:skip] -= 1
          else
            begin
              df.write Enter
              data = ""
              catch :break do
                while true
                  begin
                    IO.select([df], nil, nil, 1)
                    data << df.read_available_nonblock
                    df.write DownArrow
                  rescue IO::WaitReadable
                    throw :break
                  end
                end
              end

              write_page type, data

            ensure
              df.write Escape
              df.read_available
            end

            options[:limit] -= 1
            break if options[:limit] <= 0
          end
          df.write DownArrow
          text = df.read_available
        end

      ensure
        df.write Escape
        df.read_available
      end

      df.write DownArrow
      df.read_available

      break if options[:section] == 0
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
