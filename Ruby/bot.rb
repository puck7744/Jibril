#!/usr/local/bin/ruby
require 'discordrb'
require 'yaml'

class Location
  attr_reader :server, :channel, :role
  def initialize(server, name, role)
    #Create a custom channel and a role to view it
    @server = server
    @channel = @server.create_channel(name)
    @role = @server.create_role()
    @role.name = role
  end

  def finalize()
    @channel.delete
    @role.delete
  end
end

class Jibril < Discordrb::Commands::CommandBot
  def initialize()
    @config = YAML.load_file('config.yaml') #Load a simple configuration file
    @locations = Array.new #Remember channels and roles we've created

    #This method initializes the underlying CommandBot and Bot classes and connects to the server
    super(
      application_id: @config['authentication']['appid'],
      token: @config['authentication']['token'],
      prefix: @config['commands']['prefix']
    )

    self.prep_commands
  end

  def prep_commands()
    #Register all of the bot's available commands; note that method() is used to
    #pass instance methods as blocks for these definitions
    self.command(:goto, :min_args => 1, :max_args => 1, :usage => "!goto <location>", &method(:command_goto))
    self.command(:restart, :min_args => 0, :max_args => 1, :usage => "!restart <hard reload?>", &method(:command_restart))
  end

  def finalize()
    @locations.map!(&:finalize) #Call finalize on all locations
  end

  def command_goto(event, name)
    channelname = "#{@config['commands']['goto']['prefix']}#{name}"
    rolename = "Roleplaying in #{name}"

    #Create a Location object and add it to our list of tracked locations
    @locations.push(Location.new(event.server, channelname, rolename))
    event.respond "Done! Head on over to ##{channelname}"
  end

  def command_restart(event, *args)
    is_hard = args[0] =~ /y|yes|1|true|hard/
    event.respond "BRB!"
    self.finalize()
    if is_hard
      exec("ruby #{__FILE__}", *ARGV)
    else
      $soft_reset = true
      self.commands.each_value { |c| self.remove_command(c.name) }
      load __FILE__
      self.prep_commands
      event.respond ":heart:"
    end
  end
end

Jibril.new.run unless $soft_reset
