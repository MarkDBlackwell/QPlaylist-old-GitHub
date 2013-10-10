=begin
Author: Mark D. Blackwell (google me)
October 9, 2013 - created
October 10, 2013 - Add current time
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

require 'xmlsimple'
require 'yaml'

module Playlist
  NON_XML_KEYS = %w[ Current\ Time ]
      XML_KEYS = %w[ Artist Len Title ]
  KEYS = NON_XML_KEYS + XML_KEYS
  FIELDS = KEYS.map{|e| "[#{e} here]"}

  class Snapshot
    attr_reader :values

    def initialize
      get_non_xml_values
      get_xml_values_latest_five unless defined? @@xml_values_latest_five
      get_xml_values_now_playing unless defined? @@xml_values_now_playing
      @values = @@non_xml_values + @@xml_values_latest_five + @@xml_values_now_playing
    end

    protected

    def get_non_xml_values
      @@non_xml_values = NON_XML_KEYS.map do |k|
        case k
        when 'Current Time'
          Time.now.localtime.round.strftime '%-l:%M %p'
        else
          "(Error: key '#{k}' unknown)"
        end
      end
    end

    def get_xml_values_latest_five
      relevant_hash = xml_tree('latest-five')['Events'].first['SS32Event'].first
#     @@xml_values_latest_five = XML_KEYS.map{|k| relevant_hash[k].first.strip}
      @@xml_values_latest_five = []
    end

    def get_xml_values_now_playing
      relevant_hash = xml_tree('now-playing')['Events'].first['SS32Event'].first
      @@xml_values_now_playing = XML_KEYS.map{|k| relevant_hash[k].first.strip}
    end

    def xml_tree(s)
# See http://xml-simple.rubyforge.org/
      result = XmlSimple.xml_in "input-#{s}.xml", { KeyAttr: 'name' }
#     puts result
      print result.to_yaml if 'latest-five' == s
      result
    end
  end

  class Substitutions
    def initialize(current_values)
      @substitutions = FIELDS.zip current_values
    end

    def run(s)
      @substitutions.each{|input,output| s = s.gsub input, output}
      s
    end
  end
end

def create_output(substitutions)
  File.open 'template.html', 'r' do |f_template|
    lines = f_template.readlines
    File.open 'output.html', 'w' do |f_out|
      lines.each{|e| f_out.print substitutions.run e}
    end
  end
end

song_currently_playing = Playlist::Snapshot.new.values
substitutions = Playlist::Substitutions.new song_currently_playing
create_output substitutions
