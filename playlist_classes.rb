# require 'cgi' # See if Mustache brings it in.
require 'mustache'
require 'xmlsimple'
# require 'yaml'

module Playlist
  NON_XML_KEYS = %w[ current_time ]
      XML_KEYS = %w[ artist title ]
  KEYS = ::Playlist::NON_XML_KEYS + ::Playlist::XML_KEYS
  SONG_BLANK = ::Playlist::Song.new ::Hash[::Playlist::KEYS.product ['']]
  SECOND_KEY_LIST = %w[ date time artist title ]
  THIRD_KEY_LIST  = %w[ minute hour meridian day month year ]
  FOURTH_KEY_LIST = %w[ start_time artist title ]
  LATEST_FIVE_LENGTH = 5
  LATEST_FIVE_KEY_TABLE = (0...::Playlist::LATEST_FIVE_LENGTH).to_a.product ::Playlist::FOURTH_KEY_LIST

  class Run
    # Day before yesterday.
    def comparison_date(year_month_day) year_month_day - 60 * 60 * 24 * 2 end

    def current_compare(currently_playing)
      artist_title = currently_playing.values.drop 1
      remembered = current_song_read
      same = remembered == artist_title
      current_song_write artist_title unless same
      same
    end

    def current_hour_read() file_readlines_chomp 'current-hour.txt' end

    def current_hour_write(s) file_write 'current-hour.txt', "#{s}\n" end

    def current_song_read() file_readlines_chomp 'current-song.txt' end

    def current_song_write(artist_title) file_write 'current-song.txt', terminate_join artist_title end

    def file_append(filename, s) file_write_mode filename, 'a', s end

    def file_read(filename)
      result = nil # Define in scope.
      ::File.open(filename, 'r'){|f| result = f.read}
      result
    end

    def file_readlines(filename) file_readlines_chomp(filename).map{|e| "#{e}\n"} end

    def file_readlines_chomp(filename) file_read(filename).split "\n" end

    def file_write(filename, s) file_write_mode filename, 'w', s end

    def file_write_mode(filename, mode, s) ::File.open(filename, mode){|f| f.write s} end

    def filter_recent_songs(songs) filter_recent_songs_write *year_month_day_now, songs end

    def filter_recent_songs_write(year_month_day, year_month_day_hour_string, songs)
      ymd, s = year_month_day, year_month_day_hour_string
      unless current_hour_read.push('').first.chomp == s
        current_hour_write s
        recent_songs_manage ymd, songs
      end
    end

    def handle_change(now_playing)
      songs = recent_songs_get now_playing.values
      substitutions = ::Playlist::SubstitutionsLatestFive.new latest_five_songs_get songs
      output_create substitutions, 'latest_five.mustache', 'latest_five.html'
      output_create_recent_songs songs
      filter_recent_songs songs
    end

    def handle_change_maybe(now_playing) handle_change now_playing unless current_compare now_playing end

    def latest_five_songs_get(songs)
      padded_songs = songs.reverse + ::Array.new(::Playlist::LATEST_FIVE_LENGTH){::Playlist::SONG_BLANK}
      padded_songs.take ::Playlist::LATEST_FIVE_LENGTH
    end

    def output_create(substitutions, template, output) output_write output, (file_read template), substitutions end

    def output_create_recent_songs(songs) recent_songs_write recent_songs_supplement songs end

    def output_write(filename, s, substitutions) file_write filename, substitutions.run s end

    def recent_songs_append(s) file_append 'recent-songs.txt', s end

    def recent_songs_get(currently_playing)
# 'r+' is "Read-write, starts at beginning of file", per:
# http://www.ruby-doc.org/core-2.0.0/IO.html#method-c-new
      n = ::Time.now.localtime.round
      now = ::Time.new(n.year, n.month, n.day).strftime '%4Y %2m %2d'
      recent_songs_append terminate_join [now] + currently_playing
      recent_songs_get_songs
    end

    def recent_songs_get_songs
      lines_per_song = 4
      lines = recent_songs_get_songs_read
      lines_length = lines.length
      raise "Bad number of recent song lines" unless 0 == lines_length % lines_per_song
      (0...lines.length).each_slice(lines_per_song) do |indices|
        ::Playlist::Song.new ::Hash[::Playlist::SECOND_KEY_LIST.zip lines.values_at indices]
      end
    end

    def recent_songs_get_songs_read() file_readlines_chomp 'recent-songs.txt' end

    def recent_songs_manage(year_month_day, songs)
      reduced = recent_songs_reduce songs, comparison_date
      recent_songs_reduce_write reduced
    end

    def recent_songs_reduce(songs, comparison_date)
      big_array = []
      songs.each do |song|
        year, month, day = song['date'].split(' ').map &:to_i
        song_time = ::Time.new year, month, day
        big_array.push song.values_at ::Playlist::SECOND_KEY_LIST unless song_time < comparison_date
      end
      terminate_join big_array.flatten
    end

    def recent_songs_reduce_write(s) file_write 'recent-songs.txt', s end

    def recent_songs_supplement(songs)
      songs.map do |song|
        year, month, day = song['date']. split ' '
        clock, meridian  = song['time']. split ' '
        hour, minute     =         clock.split ':'
        pairs = ::Playlist::THIRD_KEY_LIST.map{|e| [e.to_sym, ::Kernel.eval e]}
        ::Playlist::Song.new song.merge ::Hash[pairs]
      end
    end

    def recent_songs_write(full_songs)
      ::Playlist::Songs.template_file = './recent_songs.mustache'
      file_write 'recent_songs.html', ::Playlist::Songs.new(full_songs.reverse).render
    end

    def run
      now_playing = ::Playlist::Snapshot.new.song
      output_create (::Playlist::Substitutions.new now_playing), 'now_playing.mustache', 'now_playing.html'
      handle_change_maybe now_playing
    end

    def terminate_join(a) a.map{|e| "#{e}\n"}.join '' end

    def year_month_day_now
      n = ::Time.now.localtime.round
      time = ::Time.new n.year, n.month, n.day
      s    = ::Time.new(n.year, n.month, n.day, n.hour).strftime '%4Y %2m %2d %2H'
      [time, s]
    end
  end #class

  class Snapshot
    attr_reader :song

    def initialize
      xml    = ::Playlist::ValuesXml.   new ::Playlist::XmlRead.new.xml
      values = ::Playlist::ValuesNonXml.new.values +                xml.values
      @song  = ::Playlist::Song.        new ::Hash[::Playlist::KEYS.zip values]
    end
  end

  class Song
    attr_reader :song

    def initialize(hash) @song = hash end
  end

  class Songs < ::Mustache
    attr_reader :songs

    def initialize(array_of_hashed_songs) @songs = array_of_hashed_songs end
  end

  class Substitutions
    def initialize(hash) @substitutions = hash end

    def run(s)
      @substitutions.each do |input,output|
#print '[input,output]='; p [input,output]
        s = s.gsub "{{#{input}}", CGI.escape_html output
      end
      s
    end
  end

  class SubstitutionsLatestFive < ::Playlist::Substitutions
    def initialize(latest_five)
      values = latest_five.map{|e| e.values_at ::Playlist::FOURTH_KEY_LIST}.flatten
      fields = ::Playlist::LATEST_FIVE_KEY_TABLE.map{|digit,key| "#{key}#{digit}"}
      super ::Hash[fields.zip values]
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

    def initialize() @xml = file_read 'now_playing.xml' end
  end

  class XmlRelevantHash
    attr_reader :relevant_hash

    def initialize(tree) @relevant_hash = tree['Events'].first['SS32Event'].first end
  end

  class XmlTree
    attr_reader :tree

    def initialize(xml)
# See http://xml-simple.rubyforge.org/
# http://search.cpan.org/~grantm/XML-Simple-2.20/lib/XML/Simple.pm
      @tree = ::XmlSimple.xml_in xml, {KeyAttr: 'name'}
#     print @tree.to_yaml
    end
  end
end #module
