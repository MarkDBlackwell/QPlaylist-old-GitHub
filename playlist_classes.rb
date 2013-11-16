require 'cgi'
require 'mustache'
require 'xmlsimple'
# require 'yaml'

module Playlist
  NON_XML_KEYS = %w[ current_time ]
      XML_KEYS = %w[ artist title ]
  KEYS = ::Playlist::NON_XML_KEYS + ::Playlist::XML_KEYS
  SECOND_KEY_LIST = %w[ date time artist title ]
  THIRD_KEY_LIST  = %w[ minute hour meridian day month year ]
  SONG_BLANK = ::Playlist::Song.new Hash[::Playlist::KEYS.product ['']]

  class Songs < ::Mustache
    attr_reader :songs

    def initialize(array_of_hashed_songs)
      @songs = array_of_hashed_songs
    end
  end

  class Run
    def create_output(substitutions, input_template_file, output_file)
      ::File.open input_template_file, 'r' do |f_template|
        lines = f_template.readlines
        ::File.open output_file, 'w' do |f_out|
          lines.each{|e| f_out.print substitutions.run e}
        end
      end #File
    end

    def create_output_recent_songs(songs)
      full_songs = songs.map do |song|
        year, month, day = song['date']. split ' '
        clock, meridian  = song['time']. split ' '
        hour, minute     =         clock.split ':'
        pairs = ::Playlist::THIRD_KEY_LIST.map{|e| [e.to_sym, ::Kernel.eval e]}
        ::Playlist::Song.new song.merge Hash[pairs]
      end
      ::Playlist::Songs.template_file = './recent_songs.mustache'
      ::File.open 'recent_songs.html', 'w' do |f_output|
        f_output.print ::Playlist::Songs.new(full_songs.reverse).render
      end
    end

    def current_compare(currently_playing)
      artist_title = currently_playing.values.drop 1
      remembered = current_read
      same = remembered == artist_title
      current_write artist_title unless same
      same
    end

    def current_read
      result = nil # Define in scope.
      ::File.open 'current-song.txt', 'r' do |f_current_song|
        result = f_current_song.readlines.map &:chomp
      end
      result
    end

    def current_write(artist_title)
      ::File.open 'current-song.txt', 'w' do |f_current_song|
        artist_title.each{|e| f_current_song.print "#{e}\n"}
      end
    end

    def filter_recent_songs(songs)
      n = ::Time.now.localtime.round
      year_month_day_hour_string = ::Time.new(n.year, n.month, n.day, n.hour).strftime '%4Y %2m %2d %2H'
      year_month_day             = ::Time.new n.year, n.month, n.day
      ::File.open 'current-hour.txt', 'r+' do |f_current_hour|
        unless f_current_hour.readlines.push('').first.chomp == year_month_day_hour_string
          recent_songs_reduce year_month_day, songs
          f_current_hour.rewind
          f_current_hour.truncate 0
          f_current_hour.print "#{year_month_day_hour_string}\n"
        end
      end #File
    end

    def handle_change(now_playing)
      songs = recent_songs_get now_playing.values
      latest_five = latest_five_songs_get songs
#print 'latest_five='; p latest_five
      substitutions = ::Playlist::SubstitutionsLatestFive.new latest_five
#print 'substitutions='; p substitutions
      create_output substitutions, 'latest_five.mustache', 'latest_five.html'
      create_output_recent_songs songs
      filter_recent_songs songs
    end

    def handle_change_maybe(now_playing)
      handle_change now_playing unless current_compare now_playing
    end

    def latest_five_songs_get(songs)
      songs_to_keep = 5
      (songs.reverse + Array.new(songs_to_keep){SONG_BLANK}).take songs_to_keep
    end

    def recent_songs_get(currently_playing)
# 'r+' is "Read-write, starts at beginning of file", per:
# http://www.ruby-doc.org/core-2.0.0/IO.html#method-c-new
      n = ::Time.now.localtime.round
      year_month_day = ::Time.new(n.year, n.month, n.day).strftime '%4Y %2m %2d'
      ::File.open 'recent-songs.txt', 'r+' do |f_recent_songs|
        songs = recent_songs_read f_recent_songs
        f_recent_songs.puts year_month_day
        currently_playing.each{|e| f_recent_songs.print "#{e}\n"}
        values = ([year_month_day] + currently_playing).flatten
        return songs.push Song.new Hash[::Playlist::SECOND_KEY_LIST.zip values]
      end #File
    end

    def recent_songs_read(f_recent_songs)
      lines_per_song = 4
      lines = f_recent_songs.readlines.map &:chomp
      song_count = lines.length.div lines_per_song
      (0...song_count).map do |i|
        values = (0...lines_per_song).map{|small| lines.at i * lines_per_song + small}
        Song.new Hash[::Playlist::SECOND_KEY_LIST.zip values]
      end
    end

    def recent_songs_reduce(year_month_day, songs)
      comparison_date = year_month_day - 60 * 60 * 24 * 2 # Day before yesterday.
      big_array = []
      songs.each do |song|
        year, month, day = song['date'].split(' ').map &:to_i
        song_time = ::Time.new year, month, day
        big_array.push song.values_at ::Playlist::SECOND_KEY_LIST unless song_time < comparison_date
      end
      ::File.open 'recent-songs.txt', 'w' do |f_recent_songs|
        big_array.each{|e| f_recent_songs.print "#{e}\n"}
      end
    end

    def run
      now_playing = ::Playlist::Snapshot.new.song
      substitutions = ::Playlist::Substitutions.new now_playing
      create_output substitutions, 'now_playing.mustache', 'now_playing.html'
      handle_change_maybe now_playing
    end
  end #class

  class Snapshot
    attr_reader :song

    def initialize
      xml = ::Playlist::ValuesXml.new ::Playlist::XmlRead.new.xml
      values = ::Playlist::ValuesNonXml.new.values + xml.values
      @song = ::Playlist::Song.new Hash[::Playlist::KEYS.zip values]
    end
  end

  class Song
    attr_reader :song

    def initialize(hash)
      @song = hash
    end
  end

  class Substitutions
    def initialize(hash)
      @substitutions = hash
    end

    def run(s)
      @substitutions.each do |input,output|
#print '[input,output]='; p [input,output]
        safe_output = CGI.escape_html output
        s = s.gsub "{{#{input}}", safe_output
      end
      s
    end
  end

  class SubstitutionsLatestFive < ::Playlist::Substitutions
    def initialize(latest_five)
      key_types = %w[ start_time artist title ]
      count = 5
      fields = (0...count).map(&:to_s).product(key_types).map{|digit,key| "#{key}#{digit}"}
#print 'fields='; p fields
      values = latest_five.map{|e| e.values_at key_types}.flatten
      super Hash[fields.zip values]
    end
  end

  class ValuesNonXml
    attr_reader :values

    def initialize
      @values = ::Playlist::NON_XML_KEYS.map do |k|
        case k
        when 'current_time'
          ::Time.now.localtime.round.strftime '%-l:%M %p'
        else
          raise "(Error: key '#{k}' unknown)"
        end
      end
    end
  end

  class ValuesXml
    attr_reader :values

    def initialize(xml)
      tree = ::Playlist::XmlTree.new(xml).tree
      h = ::Playlist::XmlRelevantHash.new(tree).relevant_hash
      @values = ::Playlist::XML_KEYS.map(&:capitalize).map{|k| h[k].first.strip}
    end
  end

  class XmlRead
    attr_reader :xml

    def initialize
      ::File.open 'now_playing.xml', 'r' do |f_xml|
        @xml = f_xml.read
      end
    end
  end

  class XmlRelevantHash
    attr_reader :relevant_hash

    def initialize(tree)
      @relevant_hash = tree['Events'].first['SS32Event'].first
    end
  end

  class XmlTree
    attr_reader :tree

    def initialize(xml)
# See http://xml-simple.rubyforge.org/
# http://search.cpan.org/~grantm/XML-Simple-2.20/lib/XML/Simple.pm
      @tree = ::XmlSimple.xml_in xml, { KeyAttr: 'name' }
#     puts @tree
#     print @tree.to_yaml
    end
  end
end #module
