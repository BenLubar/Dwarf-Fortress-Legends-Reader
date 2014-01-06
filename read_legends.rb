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
  full_name = ""
  first_name = ""

  data.force_encoding Encoding::UTF_8
  data.gsub! /\e\[[0-9]*;[23]H/, "\n"
  data.gsub! /\e\[[0-9;]*./, " "
  data.gsub! /\e./, " "
  data.gsub! /(\u0008|\u000f|\u2022|\u2502|\u2191|\u2193)/, " "

  $fault_data = [$fault_data, data]

  open "#{Types[type][:pre]}-#{data[/^\s*(.*?)\s+(was\s+(a|the)|could\s+be\s+found\s+(with)?in)\s+/, 1].paramcase}.html", "w" do |f|
    f.puts <<-EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>#{data[/^\s*(.*?)\s+(was\s+(a|the)|could\s+be\s+found\s+(with)?in)\s+/, 1]} (#{Types[type][:name]})</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="style.css">
<script src="script.js" async defer></script>
</head>
<body>
<p>
EOF

    line_accum = ""

    link = proc do |prefix, name|
      param = name.paramcase
      if param == full_name.paramcase or param == first_name.paramcase
        name
      else
        "<a href=\"#{prefix}-#{param}.html\">#{name}</a>"
      end
    end

    print_accum = proc do
      line_accum.strip!

      if first_text_printed
        line_accum.gsub! /,\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?)\s+(struck\s+down|shot\s+and\s+killed|attacked|was\s+struck\s+down\s+by|was\s+shot\s+and\s+killed\s+by|devoured|ambushed|fought\s+with|happened\s+upon|confronted|married)\s+((the\s+[a-z\s\-]+)?([A-Z][^\.]*?)|an?\s+[a-z\s\-]+?)(\s+of\s+(The\s+[A-Z][^\.]*?))?(\s+in\s+([A-Z][^\.]*?))?\.(\s+While\s+defeated,\s+the\s+latter\s+escaped\s+unscathed\.)?\z/ do
          of_ent = ""
          of_ent = " of #{link.call "ent", $8}" if $8
          in_site = ""
          in_site = " in #{link.call "site", $10}" if $10
          if $5
            ", #{$1}#{link.call "fig", $2} #{$3} #{$5}#{link.call "fig", $6}#{of_ent}#{in_site}.#{$11}"
          else
            ", #{$1}#{link.call "fig", $2}  #{$3} #{$4}#{of_ent}#{in_site}.#{$11}"
          end
        end or line_accum.gsub! /,\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?)'s\s+([a-z\s\-]+\s+was\s+[a-z\s\-]+\s+by)\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?)\.\z/ do
          ", #{$1}#{link.call "fig", $2}'s #{$3} #{$4}#{link.call "fig", $5}."
        end or line_accum.gsub! /,\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?)\s+became\s+(a\s+hero\s+in\s+the\s+eyes|an\s+enemy|a\s+lord|a\s+lady|the\s+[a-z\s\-]+?)\s+of\s+([A-Z][^\.]*?)\.\z/ do
          ", #{$1}#{link.call "fig", $2} became #{$3} of #{link.call "ent", $4}."
        end or line_accum.gsub! /,\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?)\s+of\s+([A-Z][^\.]*?)\s+(created\s+the\s+position\s+of\s+[a-z\s\-]+\s+as\s+a\s+matter\s+of\s+course)\.\z/ do
          ", #{$1}#{link.call "fig", $2} of #{link.call "ent", $3} #{$4}."
        end or line_accum.gsub! /,\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?)\s+ruled\s+from\s+([A-Z][^\.]*?)\s+of\s+(The\s+[A-Z][^\.]*?)\s+in\s+([A-Z][^\.]*?)\.\z/ do
          ", #{$1}#{link.call "fig", $2} ruled from #{link.call "site", $3} of #{link.call "ent", $4} in #{link.call "site", $5}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+(accepted|rejected)\s+an\s+offer\s+of\s+peace\s+from\s+([A-Z][^\.]*?)\.\z/ do
          ", #{link.call "ent", $1} #{$2} an offer of peace from #{link.call "ent", $3}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+fooled\s+([A-Z][^\.]*?)\s+into\s+believing\s+([a-z]+)\s+was\s+([A-Z][^\.]*?)\.\z/ do
          ", #{link.call "fig", $1} fooled #{link.call "ent", $2} into believing #{$3} was #{link.call "fig", $4}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+attacked\s+(The\s+[A-Z][^\.]*?)\s+(of\s+(The\s+[A-Z][^\.]*?)\s+)?at\s+([A-Z][^\.]*?)\.\s+(The\s+[a-z\s\-]+)?([A-Z][^\.]*?)\s+led\s+the\s+attack(,\s+and\s+the\s+defenders\s+were\s+led\s+by\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?))?\.\z/ do
          of_ent = ""
          of_ent = " of #{link.call "ent", $4} " if $4
          and_the_defenders = ""
          and_the_defenders = ", and the defenders were led by #{$9}#{link.call "fig", $10}" if $10
          ", #{link.call "ent", $1} attacked #{link.call "site", $2} #{of_ent}at #{link.call "site", $5}. #{$6}#{link.call "fig", $7} led the attack#{and_the_defenders}."
        end or line_accum.gsub! /,\s+(the\s+[a-z\s\-]+)?([A-Z][^\.]*?)\s+(settled\s+in|began\s+wandering|became\s+a\s+[a-z\s\-]+?\s+in|began\s+scouting\s+the\s+area\s+around)\s+([A-Z][^\.]*?)\.\z/ do
          ", #{$1}#{link.call "fig", $2} #{$3} #{link.call "site", $4}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)(\s+of\s+(The\s+[A-Z][^\.]*?))?\s+(constructed|founded|launched\s+an\s+expedition\s+to\s+reclaim)\s+([A-Z][^\.]*?)(\s+in\s+([A-Z][^\.]*?))?\.\z/ do
          of_ent = ""
          of_ent = " of #{link.call "ent", $3}" if $3
          in_site = ""
          in_site = " in #{link.call "site", $7}" if $7
          ", #{link.call "ent", $1}#{of_ent} #{$4} #{link.call "site", $5}#{in_site}."
        end or line_accum.gsub! /,\s+([A-Z][^\.]*?)\s+defeated\s+([A-Z][^\.]*?)\s+and\s+(pillaged)\s+([A-Z][^\.]*?)\.\z/ do
          ", #{link.call "ent", $1} defeated #{link.call "ent", $2} and #{$3} #{link.call "site", $4}."
        end
      else
        line_accum.gsub! /\A(.*?)\s+(was\s+(a|the)|could\s+be\s+found\s+(with)?in)\s+/ do
          # Don't lose $1
          full_name = $1
          verb = $2
          first_name = full_name[/\A\S+/] or ""
          "<strong>#{full_name}</strong> #{verb} "
        end
        line_accum.gsub! /\s+in\s+([A-Z][^\.]*?)\.\z/ do
          " in #{link.call "site", $1}."
        end
        # Work around Masterwork weirdness.
        line_accum.gsub! /(,)?([a-z\s\-]+), +youth, +writing, +wisdom, +the +wind, +the +weather, +wealth, +water, +war, +volcanos, +victory, +valor, +twilight, +truth, +trickery, +trees, +treachery, +travelers, +trade, +torture, +thunder, +thralldom, +theft, +the +sun, +suicide, +strength, +storms, +the +stars, +speech, +song, +the +sky, +silence, +the +seasons, +scholarship, +salt, +sacrifice, +rumors, +rulership, +rivers, +revenge, +revelry, +rebirth, +rainbows, +the +rain, +pregnancy, +poetry, +plants, +persuasion, +peace, +painting, +order, +oceans, +oaths, +nightmares, +the +night, +nature, +music, +murder, +muck, +mountains, +the +moon, +mist, +misery, +minerals, +metals, +mercy, +marriage, +lust, +luck, +loyalty, +love, +longevity, +lightning, +light, +lies, +laws, +lakes, +labor, +justice, +jewels, +jealousy, +inspiration, +hunting, +hospitality, +healing, +happiness, +generosity, +games, +gambling, +freedom, +fortresses, +forgiveness, +food, +fishing, +fish, +fire, +festivals, +fertility, +fate, +fame, +family, +earth, +duty, +dusk, +dreams, +disease, +discipline, +depravity, +deformity, +death, +day, +the +dawn, +darkness, +dance, +creation, +crafts, +courage, +consolation, +coasts, +children, +charity, +chaos, +caverns, +boundaries, +blight, +birth, +beauty, +balance, +art, +animals +and +agriculture/ do
          if $1
            " and#{$2}"
          else
            $2
          end
        end
      end
      f.puts line_accum
    end

    print_related = proc do
      header_printed = false
      case section
      when /\ARelated\s+Entities\z/
        line_accum.gsub! /\A(.+?)\s+\(/ do
          "#{link.call "ent", $1} ("
        end
      when /\ARelated\s+Historical\s+Figures\z/
        line_accum.gsub! /\A([^,]+?)(\s+the\s+[a-z\s\-]+)?,/ do
          "#{link.call "fig", $1}#{$2},"
        end
      when /(?<!\sOther)\s+Kills?\z/
        line_accum.gsub! /\A(.*?)(\s+the\s+[a-z\s+\-]+)/ do
          "#{link.call "fig", $1}#{$2}"
        end
      when /(?<!\sNotable)\s+Kills?\z/
        line_accum.gsub! /\s+in\s+([A-Z].*?)\z/ do
          " in #{link.call "site", $1}"
        end
      end
      f.puts "<li>#{line_accum}</li>"
    end

    data.each_line do |line|
      line.strip!
      line_accum.gsub! /\s\s+/, " "

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
            line_accum = ""
            first_related_entity = false
          else
            print_related.call
            f.puts "</ul>"
            line_accum = ""
          end
          f.puts
          f.puts "<h2 id=\"#{line[/\ARelated.*\z|((Other|Notable)\s+)?Kills?\z/].paramcase}\">#{line}</h2>"
          f.puts "<ul>"
          section = line
          header_printed = true
        elsif !line.empty?
          if line[/\A[a-z]/]
            line_accum << " " << line
          else
            print_related.call unless line_accum.empty?
            line_accum = line
          end
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
      print_related.call
      f.puts "</ul>"
    else
      print_accum.call
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

  catch :limit_reached do
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
          df.read_available
          df.write UpArrow
          df.read_available
          df.write DownArrow
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
              throw :limit_reached if options[:limit] <= 0
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

        throw :limit_reached if options[:section] == 0
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
end
