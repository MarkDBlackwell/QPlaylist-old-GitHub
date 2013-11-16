=begin
Author: Mark D. Blackwell (google me)
October 9, 2013 - created
October 10, 2013 - Add current time
October 24, 2013 - Escape the HTML
October 31, 2013 - Add latest five songs
November 8, 2013 - Use Mustache format
November 11, 2013 - Generate recent songs in HTML

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
mustache
xml-simple
=end

require './playlist_classes'

::Playlist::Run.new.run
