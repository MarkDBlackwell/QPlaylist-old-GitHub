Installation instructions:

The entire directory should be installed on a user's computer (not on the WideOrbit server computer).

On the WideOrbit server, the user must create another directory: 'NowPlaying'.

Inside this, they must place an HTML template file. (Please see example file, 'template-sample.html'.)

Also, in it they may place a file of FTP commands (if they cannot FTP to the webserver from their own, user computer).


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

Which Ruby versions supported?

Known to work on Ruby
2.0.0p247

Go to https://www.ruby-lang.org . Click the top tab, 'Downloads'.
Search down for 'Windows' and 'RubyInstaller'. Go there and then click the Download button.

On the resulting page, click (to download) the latest (highest-numbered) Ruby 2.0.0 version, with 'x64' only if you're running on a 64-bit machine.


Once Ruby is installed (successfully), do this for each of the required gems, mentioned above:

gem install {gem name}

License: GPL 3.0.
