rem Author: Mark D. Blackwell (google me)
rem October 9, 2013 - created
rem October 10, 2013 - comment out firewall-blocked ftp
rem Description:

rem This Windows batch file:
rem 1. obtains the input for a certain program;
rem 2. runs that program;
rem 3. copies the program's output to another directory (wherever desired);
rem 4. runs an FTP program to upload that output file.

rem This batch file, and the associated program,
rem along with its input and output files,
rem all reside in the same directory.

rem See the program's source code file for a description.

rem Per http://stackoverflow.com/questions/357315/get-list-of-passed-arguments-in-windows-batch-script-bat
rem %~p0 is the path to the script.
c:
rem %Change to the batch file's directory:
cd %~p0
start /wait cmd /C copy /Y z:\NowPlaying\Template.html template.html
start /wait cmd /C copy /Y z:\NowPlaying.XML input-now-playing.xml
start /wait cmd /C copy /Y z:\5played.XML input-latest-five.xml
start /wait cmd /C ruby playlist.rb
start /wait cmd /C copy /Y output.html z:\NowPlaying\NowPlaying.html

rem If FTP can succeed locally, uncomment this:
rem start /wait cmd /C ftp -s:z:\NowPlaying\NowPlaying.ftp

rem If FTP fails locally, then FTP from the z: drive's server computer.
