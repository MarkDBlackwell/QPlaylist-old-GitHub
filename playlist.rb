=begin
Author: Mark D. Blackwell (google me)
October 9, 2013 - created
October 10, 2013 - Add current time
October 24, 2013 - Escape the HTML
October 31, 2013 - Add latest five songs
November 8, 2013 - Use Moustache format

Description:

BTW, WideOrbit is a large software system
used in radio station automation.

This program, along with its input and output files,
and a Windows batch file, all reside in the same directory.

The program converts the desired information
(about whatever song is now playing)
from a certain XML file format, produced by WideOrbit,
into an HTML format, suitable for a webpage's iFrame.

The program reads an HTML template file,
substitutes the XML file's information into it,
and thereby produces its output HTML file.

Required gems:
xml-simple
=end

require 'cgi'
require 'xmlsimple'
# require 'yaml'

module Playlist
  NON_XML_KEYS = %w[ current_time ]
      XML_KEYS = %w[ artist title ]
  KEYS = NON_XML_KEYS + XML_KEYS

  class Snapshot
    attr_reader :values

    def initialize
      get_non_xml_values
      get_xml_values unless defined? @@xml_values
      @values = @@non_xml_values + @@xml_values
    end

    protected

    def get_non_xml_values
      @@non_xml_values = NON_XML_KEYS.map do |k|
        case k
        when 'current_time'
          Time.now.localtime.round.strftime '%-l:%M %p'
        else
          "(Error: key '#{k}' unknown)"
        end
      end
    end

    def get_xml_values
      relevant_hash = xml_tree['Events'].first['SS32Event'].first
      @@xml_values = XML_KEYS.map(&:capitalize).map{|k| relevant_hash[k].first.strip}
    end

    def xml_tree
# See http://xml-simple.rubyforge.org/
      result = XmlSimple.xml_in 'now_playing.xml', { KeyAttr: 'name' }
#     puts result
#     print result.to_yaml
      result
    end
  end

  class Substitutions
    def initialize(fields, current_values)
      @substitutions = fields.zip current_values
    end

    def run(s)
      @substitutions.each do |input,output|
#print '[input,output]='; p [input,output]
        safe_output = CGI.escape_html output
        s = s.gsub input, safe_output
      end
      s
    end
  end

  class NowPlayingSubstitutions < Substitutions
    def initialize(current_values)
      fields = KEYS.map{|e| "{{#{e}}}"}
      super fields, current_values
    end
  end

  class LatestFiveSubstitutions < Substitutions
    def initialize(current_values)
      key_types = %w[ start_time artist title ]
      count = 5
      fields = (1..count).map(&:to_s).product(key_types).map{|digit,key| "{{#{key}#{digit}}}"}
#print 'fields='; p fields
      super fields, current_values
    end
  end
end

def create_output(substitutions, input_template_file, output_file)
  File.open input_template_file, 'r' do |f_template|
    lines = f_template.readlines
    File.open output_file, 'w' do |f_out|
      lines.each{|e| f_out.print substitutions.run e}
    end
  end
end

def build_recent(f_recent_songs, currently_playing)
  input_file  = 'recent_songs.moustache'
  output_file = 'recent_songs.html'
end

def compare_recent(currently_playing)
  remembered, artist_title, same = nil, nil, nil # Define in scope.
  File.open 'current-song.txt', 'r+' do |f_current_song|
    remembered = f_current_song.readlines.map &:chomp
    artist_title = currently_playing.drop 1
    same = remembered == artist_title
    unless same
      f_current_song.rewind
      f_current_song.truncate 0
      artist_title.each{|e| f_current_song.print "#{e}\n"}
    end
  end
  same ? 'same' : nil
end

def get_recent_songs(currently_playing)
# 'r+' is "Read-write, starts at beginning of file", per:
# http://www.ruby-doc.org/core-2.0.0/IO.html#method-c-new

  n = Time.now
  year_month_day = Time.new(n.year, n.month, n.day).strftime '%4Y %2m %2d'

  times, artists, titles = nil, nil, nil # Define in scope.
  File.open 'recent-songs.txt', 'r+' do |f_recent_songs|
    times, artists, titles = read_recent_songs f_recent_songs
# Push current song:
    times.  push currently_playing.at 0
    artists.push currently_playing.at 1
    titles. push currently_playing.at 2
    f_recent_songs.puts year_month_day
    currently_playing.each{|e| f_recent_songs.print "#{e}\n"}
  end
  [times, artists, titles]
end

def read_recent_songs(f_recent_songs)
  times, artists, titles = [], [], []
  lines_per_song = 4
  a = f_recent_songs.readlines.map &:chomp
  song_count = a.length.div lines_per_song
  (0...song_count).each do |i|
# For now, ignore date, which is at:
#                     i * lines_per_song + 0
    times.  push a.at i * lines_per_song + 1
    artists.push a.at i * lines_per_song + 2
    titles. push a.at i * lines_per_song + 3
  end
  [times, artists, titles]
end

def get_latest_five_songs(times, artists, titles)
  songs_to_keep = 5
  song_count = titles.length
  songs_to_drop = song_count <= songs_to_keep ? 0 : song_count - songs_to_keep
  [ (times.  drop songs_to_drop),
    (artists.drop songs_to_drop),
    (titles. drop songs_to_drop) ].transpose.reverse.
      fill(['','',''], song_count...songs_to_keep).flatten
end

now_playing = Playlist::Snapshot.new.values
now_playing_substitutions = Playlist::NowPlayingSubstitutions.new now_playing
create_output now_playing_substitutions, 'now_playing.moustache', 'now_playing.html'


unless 'same' == (compare_recent now_playing)
  times, artists, titles = get_recent_songs now_playing
  latest_five = get_latest_five_songs times, artists, titles
#print 'latest_five='; p latest_five
  latest_five_substitutions = Playlist::LatestFiveSubstitutions.new latest_five
#print 'latest_five_substitutions='; p latest_five_substitutions
  create_output latest_five_substitutions, 'latest_five.moustache', 'latest_five.html'
end
