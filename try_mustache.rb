require 'mustache'

class Song
  attr_reader :value

  def initialize(artist, day, hour, minute, month, time, title, year)
    @value = {
          artist: artist,
          day:    day,
          hour:   hour,
          minute: minute,
          month:  month,
          time:   time,
          title:  title,
          year:   year,
        }
  end
end

class Songs < Mustache
  def initialize(a)
    @a = a
  end
  def songs
    @a
  end
end

Songs.template_file = './recent_songs.mustache'
names = %w[ artist day hour minute month time title year ]
print 'names='; p names
songs = (1..2).map{ Song.new(*names).value}
print 'songs='; p songs
a = Songs.new songs
print a.render

