#!/usr/local/bin/ruby
require 'discordrb'
require 'yaml'

Dir["src/*.rb"].each {|file| load file }

if !Jibril.running
  instance = Jibril.new

  #Make sure we shut down cleanly on SIGINT
  Signal.trap('INT') { instance.finalize(); exit }
  
  instance.run
end
