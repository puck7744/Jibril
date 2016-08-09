#!/usr/local/bin/ruby
require 'discordrb'
require 'yaml'

Dir["src/*.rb"].each {|file| require file }

begin
  instance = Jibril.new
  instance.run unless Jibril.running
rescue Exception => e
  puts e.message
  (instance.finalize) rescue nil;
  Process.reload
end
