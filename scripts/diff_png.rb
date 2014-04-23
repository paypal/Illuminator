#!/usr/bin/env ruby
require 'rubygems'
require 'chunky_png'


if 2 > ARGV.length
  puts
  puts "Usage: diff_png.rb <file1> <file2>"
  puts
  puts "Compare two images and print the number of pixels that differ."
  puts "  file1 may contain pixel values of #FF00FF, which will be ignored"
  puts
  exit 1
end

$stderr.print "Loading master image..."
img1 = ChunkyPNG::Image.from_file(ARGV[0])
$stderr.puts "done: #{img1.metadata}"

$stderr.print "Loading candidate image..."
img2 = ChunkyPNG::Image.from_file(ARGV[1])
$stderr.puts "done: #{img2.metadata}"

diff = 0
mask = 0
maskpixel = ChunkyPNG::Color.rgb(255, 0, 255) # same as ChunkyPNG::Color.rgba(255, 0, 255, 255)

$stderr.print "processing"
img1.height.times do |y|
  $stderr.print "."
  img1.row(y).each_with_index do |pixel, x|
    if pixel == maskpixel
      mask += 1
    elsif pixel != img2[x,y]
      diff += 1
    end
  end
end
$stderr.puts

# results are here
puts "pixels (total): #{img1.pixels.length}"
puts "pixels masked: #{mask}"
puts "pixels changed: #{diff}"

if 0 < diff
  exit 1
end
