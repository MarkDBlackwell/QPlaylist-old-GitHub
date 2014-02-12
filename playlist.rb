=begin
Author: Mark D. Blackwell (google me)
October 9, 2013 - created
October 10, 2013 - Add current time
October 24, 2013 - Escape the HTML
October 31, 2013 - Add latest five songs
November 8, 2013 - Use Mustache format
November 11, 2013 - Generate recent songs in HTML

Description:

See README.md.
=end

require './playlist_classes'

::Playlist::Run.new.run
