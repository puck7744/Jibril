#!/usr/local/bin/ruby
require 'discordrb'
require 'yaml/store'

Dir["src/*.rb"].each {|file| load file }
Dir["src/commands/*.rb"].each {|file| load file }

Jibril.new.run()
