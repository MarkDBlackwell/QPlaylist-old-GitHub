rem Author: Mark D. Blackwell
rem Change dates:
rem November 13, 2013 - created
rem
rem Usage:
rem   live-update.vbs {file path of WideOrbit-generated file, NowPlaying.xml}
rem Usage example:
rem   live-update.vbs "\\HOLMES\D\NowPlaying.xml"
rem
rem BTW, WideOrbit is a large software system
rem used in radio station automation.
rem
rem==============
rem References:
rem   http://www.devguru.com/technologies/VBScript/14075
rem   http://rosettacode.org/wiki/Here_document#VBScript
rem   http://wiki.mcneel.com/developer/vbsstatements

Const CreateIfNotExist = True
Const ForWriting = 2
Const OpenAsAscii = 0
Const PromptPrefix = "Current Song "
Const MessageTerminating = "...terminating."
Const FilePathArgumentPosition = 0
Const ErrorExitCodeMissingArgument = 1
Const ErrorExitCodeFilePathBad = 2
Const ErrorExitCodeFileNonexistent = 3

Dim filesys, filePath, outputTextStream
Dim n
Dim stringOne, stringTwo, stringThree
Dim artist, title
Dim xmlOutputString
Dim startupMessage
Dim promptArtist, promptTitle

n = Chr(13) & Chr(10)

rem Most of these fields are ignored by the Simple XML parser.

stringOne = _
"<?xml version='1.0' encoding='ISO-8859-1'?>"              & n & _
"<?xml-stylesheet type='text/xsl' href='NowPlaying.xsl'?>" & n & _
"<NowPlaying>"                     & n & _
"<Call>WTMD-FM</Call>"             & n & _
"<Events>"                         & n & _
"<SS32Event pos='0' valid='true'>" & n & _
_
"<CatId>MUS</CatId>"               & n & _
"<CutId>00PB</CutId>"              & n & _
"<Type>SONG</Type>"                & n & _
"<SecondsRemaining>  </SecondsRemaining>"  & n & _
"<Title><![CDATA["

stringTwo = _
"]]></Title>"       & n & _
"<Artist><![CDATA["

stringThree = _
"]]></Artist>"              & n & _
"<Intro>00</Intro>"         & n & _
"<Len>04:57</Len>"          & n & _
"<Raw><![CDATA[ ]]></Raw>"  & n & _
_
"</SS32Event>"              & n & _
"</Events>"                 & n & _
"</NowPlaying>"

startupMessage = _
"Website Playlist Manual Update Program. " & _
"Hit Ctrl-C to end." & n & n & _
"Please enter..." & n

promptArtist = PromptPrefix & "Artist: "
promptTitle  = PromptPrefix &  "Title: "

If WScript.Arguments.Count < 1 Then
    WScript.StdOut.Write _
    "The required command-line argument is missing" & _
    MessageTerminating & n
    WScript.Quit(ErrorExitCodeMissingArgument)
End If

Set filesys = CreateObject("Scripting.FileSystemObject")

rem Set filePath to something like:
rem "\\HOLMES\D\NowPlaying.xml"

filePath = WScript.Arguments(FilePathArgumentPosition)
rem WScript.StdOut.Write filePath & n

rem Normally, this file will exist, already.
rem (So, this check helps us to validate the argument.):

If Not filesys.FileExists(filePath) Then
    WScript.StdOut.Write _
    "Specified by a command-line argument, the file is nonexistent" & _
    MessageTerminating & n
    WScript.Quit(ErrorExitCodeFileNonexistent)
End If

WScript.StdOut.Write startupMessage

Do While True
  WScript.StdOut.Write promptTitle
  title = WScript.StdIn.ReadLine

  WScript.StdOut.Write promptArtist
  artist = WScript.StdIn.ReadLine

  xmlOutputString = _
  stringOne    & title  & _
  stringTwo    & artist & _
  stringThree  & n

  Set outputTextStream = filesys.OpenTextFile(filePath, ForWriting, CreateIfNotExist, OpenAsAscii)

  outputTextStream.Write xmlOutputString

  outputTextStream.Close

  WScript.StdOut.Write "Updated." & n & n
Loop
