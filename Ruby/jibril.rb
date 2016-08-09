#!/usr/local/bin/ruby
require 'discordrb'
require 'yaml'

Dir["src/*.rb"].each {|file| load file }

if !Jibril.running
  begin
    instance = Jibril.new
    Signal.trap('INT') { instance.finalize(); exit }
    instance.run
  rescue Exception => e
    puts e.message
    (instance.finalize) rescue nil; #Suppress errors because of a shortcoming in discordrb
    Process.reload
  end
end
