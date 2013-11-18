# require 'cgi' # See if Mustache brings it in.
require 'mustache'
require 'xmlsimple'
# require 'yaml'

module Playlist
  NON_XML_KEYS = %w[ current_time ]
      XML_KEYS = %w[ artist title ]
  KEYS = NON_XML_KEYS + XML_KEYS
  SONG_BLANK = Song.new ::Hash[KEYS.product ['']]
  SECOND_KEY_LIST = %w[ date time artist title ]
  THIRD_KEY_LIST  = %w[ minute hour meridian day month year ]
  FOURTH_KEY_LIST = %w[ start_time artist title ]
  LATEST_FIVE_LENGTH = 5
  LATEST_FIVE_KEY_TABLE = (0...LATEST_FIVE_LENGTH).to_a.product FOURTH_KEY_LIST

  module MustacheClasses
    class Songs < ::Mustache
      attr_reader :songs

      def initialize(array_of_hashed_songs) @songs = array_of_hashed_songs end
    end
  end

  class MyDataAccess
    def self.current_hour_read() basic_array_read 'current-hour.txt' end

    def self.current_hour_write(s) basic_write 'current-hour.txt', s end

    def self.current_song_read() basic_array_read 'current-song.txt' end

    def self.current_song_write(s) basic_write 'current-song.txt', s end

    def self.output_write(filename, s) basic_write filename, s end

    def self.recent_songs_append(s) basic_append 'recent-songs.txt', s end

    def self.recent_songs_get_songs_read() basic_array_read 'recent-songs.txt' end

    def self.recent_songs_reduce_write(s) basic_write 'recent-songs.txt', s end

    def self.recent_songs_write(s) basic_write 'recent_songs.html', s end

    private

    def self.basic_append(filename, s) MyFile.file_append filename, s end

    def self.basic_array_read(filename) MyFile.file_readlines_chomp filename end

    def self.basic_write(filename, s) MyFile.file_write filename, s end
  end

  class MyFile
    def self.file_append(filename, s) file_write_mode filename, 'a', s end

    def self.file_read(filename)
      result = nil # Define in scope.
      ::File.open(filename, 'r'){|f| result = f.read}
      result
    end

    def self.file_readlines(filename) file_readlines_chomp(filename).map{|e| "#{e}\n"} end

    def self.file_readlines_chomp(filename) file_read(filename).split "\n" end

    def self.file_write(filename, s) file_write_mode filename, 'w', s end

    def self.terminate_join(a) a.map{|e| "#{e}\n"}.join '' end

    private

    def self.file_write_mode(filename, mode, s) ::File.open(filename, mode){|f| f.write s} end
  end

  class MyTime
    # Day before yesterday.
    def self.comparison_date(year_month_day) year_month_day - 60 * 60 * 24 * 2 end

    def self.time_now() ::Time.now.localtime.round end

    def self.year_month_day(time) t = time; ::Time.new t.year, t.month, t.day end

    def self.year_month_day_hour(time) t = time; ::Time.new t.year, t.month, t.day, t.hour end

    def self.year_month_day_hour_string(time) year_month_day_hour(time).strftime '%4Y %2m %2d %2H' end

    def self.year_month_day_now() year_month_day time_now end

    def self.year_month_day_string(time) year_month_day(time).strftime '%4Y %2m %2d' end

    def self.year_month_day_string_now() year_month_day_string time_now end
  end

  class Run
    def current_compare(currently_playing)
      artist_title = currently_playing.values.drop 1
      remembered = MyDataAccess.current_song_read
      same = remembered == artist_title
      MyDataAccess.current_song_write current_song_string artist_title unless same
      same
    end

    def current_song_string(artist_title) MyFile.terminate_join artist_title end

    def filter_recent_songs(songs) filter_recent_songs_write *year_month_day_hour_info, songs end

    def filter_recent_songs_write(year_month_day, year_month_day_hour_string, songs)
      ymd, ymdh_s = year_month_day, year_month_day_hour_string
      unless MyDataAccess.current_hour_read.push('').first.chomp == ymdh_s
        MyDataAccess.current_hour_write MyFile.terminate_join [ymdh_s]
        recent_songs_manage ymd, songs
      end
    end

    def handle_change(now_playing)
      songs = recent_songs_get now_playing.values
      substitutions = SubstitutionsLatestFive.new latest_five_songs_get songs
      output_create substitutions, 'latest_five.mustache', 'latest_five.html'
      output_create_recent_songs songs
      filter_recent_songs songs
    end

    def handle_change_maybe(now_playing) handle_change now_playing unless current_compare now_playing end

    def latest_five_songs_get(songs)
      padded_songs = songs.reverse + ::Array.new(LATEST_FIVE_LENGTH){SONG_BLANK}
      padded_songs.take LATEST_FIVE_LENGTH
    end

    def output_create(substitutions, template, output)
      input = MyFile.file_read template
      s = output_string input, substitutions
      MyDataAccess.output_write output, s
    end

    def output_create_recent_songs(songs)
      MyDataAccess.recent_songs_write recent_songs_string recent_songs_supplement songs
    end

    def output_string(input, substitutions) substitutions.run input end

    def recent_songs_get(currently_playing)
      now = MyTime.year_month_day_string_now
      MyDataAccess.recent_songs_append MyFile.terminate_join [now] + currently_playing
      recent_songs_get_songs
    end

    def recent_songs_get_songs
      lines_per_song = 4
      lines = MyDataAccess.recent_songs_get_songs_read
      lines_length = lines.length
      raise 'Bad number of recent song lines' unless 0 == lines_length % lines_per_song
      (0...lines.length).each_slice(lines_per_song) do |indices|
        Song.new ::Hash[SECOND_KEY_LIST.zip lines.values_at indices]
      end
    end

    def recent_songs_manage(year_month_day, songs)
      reduced = recent_songs_reduce songs, MyTime.comparison_date
      MyDataAccess.recent_songs_reduce_write reduced
    end

    def recent_songs_reduce(songs, comparison_date)
      keep_songs = songs.reject do |song|
        year, month, day = song['date'].split(' ').map &:to_i
        song_time = ::Time.new year, month, day
        song_time < comparison_date
      end
      MyFile.terminate_join keep_songs.map{|e| e.values_at SECOND_KEY_LIST}.flatten
    end

    def recent_songs_string(full_songs)
      MustacheClasses::Songs.template_file = './recent_songs.mustache'
      MustacheClasses::Songs.new(full_songs.reverse).render
    end

    def recent_songs_supplement(songs)
      songs.map do |song|
        year, month, day = song['date']. split ' '
        clock, meridian  = song['time']. split ' '
        hour, minute     =         clock.split ':'
        pairs = THIRD_KEY_LIST.map{|e| [e.to_sym, ::Kernel.eval e]}
        Song.new song.merge ::Hash[pairs]
      end
    end

    def run
      now_playing = Snapshot.new.song
      substitutions = Substitutions.new now_playing
      output_create substitutions, 'now_playing.mustache', 'now_playing.html'
      handle_change_maybe now_playing
    end

    def year_month_day_hour_info
      n = MyTime.time_now
      [   MyTime.year_month_day             n ].push \
          MyTime.year_month_day_hour_string n
    end
  end #class

  class Snapshot
    attr_reader :song

    def initialize
      xml    = ValuesXml.   new XmlRead.new.xml
      values = ValuesNonXml.new.values +    xml.values
      @song  = Song.        new ::Hash[KEYS.zip values]
    end
  end

  class Song
    attr_reader :song

    def initialize(hash) @song = hash end
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

  class SubstitutionsLatestFive < Substitutions
    def initialize(latest_five)
      values = latest_five.map{|e| e.values_at FOURTH_KEY_LIST}.flatten
      fields = LATEST_FIVE_KEY_TABLE.map{|digit,key| "#{key}#{digit}"}
      super ::Hash[fields.zip values]
    end
  end

  class ValuesNonXml
    attr_reader :values

    def initialize
      @values = NON_XML_KEYS.map do |k|
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
      tree = XmlTree.new(xml).tree
      h = XmlRelevantHash.new(tree).relevant_hash
      @values = XML_KEYS.map(&:capitalize).map{|k| h[k].first.strip}
    end
  end

  class XmlRead
    attr_reader :xml

    def initialize() @xml = MyFile.file_read 'now_playing.xml' end
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
