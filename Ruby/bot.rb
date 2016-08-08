#!/usr/local/bin/ruby
require 'discordrb'
require 'yaml'

class Location
  attr_reader :server, :channel, :role
  def initialize(server, name, role)
    #Create a custom channel and a role to view it
    @server = server

    @role = @server.create_role()
    @role.name = role

    @channel = @server.create_channel(name)
    @channel.define_overwrite(@server.default_role, 0, 9007199254740991) #No permissions
    @channel.define_overwrite(@role.id, 67177472, 0)#Basic permissions
  end

  def finalize()
    @channel.delete
    @role.delete
  end
end

#Patch method for Server to get the default role
class Discordrb::Server
  def default_role
    self.role(@id)
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

    self.prepare
  end

  def prepare()
    #Register all of the bot's available commands; note that method() is used to
    #pass instance methods as blocks for these definitions
    self.command(
      :goto,
      :min_args => 1,
      :max_args => 1,
      :usage => "!goto <location>",
      &method(:command_goto)
    )
    self.command(
      :reload,
      :min_args => 0,
      :max_args => 1,
      :usage => "!reload [hard?]",
      :permission_level => 10,
      &method(:command_restart)
    )
    self.command(:roles) { |e|
      e.respond "Server roles:"
      e.server.roles.each { |r|
        e.respond "#{r.name} (#{r.id})"
      }
      e.respond e.server.default_role.name
    }
    #Do setup after connection to server is complete
    self.ready {
      @config['authentication']['admins'].each { |entry|
        self.set_user_permission(entry, 10)
        self.users[entry].pm("Jibril bot is now online") if self.users[entry]
      }
    }
  end

  def finalize()
    @locations.map!(&:finalize) #Call finalize on all locations
    @locations = Array.new
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
    self.finalize()
    if is_hard
      exec("ruby #{__FILE__}", *ARGV)
    else
      $soft_reset = true
      self.commands.each_value { |c| self.remove_command(c.name) }
      load __FILE__
      self.prepare
      event.respond "Done! :heart:"
    end
  end
end

Jibril.new.run unless $soft_reset
