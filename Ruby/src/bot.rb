class Jibril < Discordrb::Commands::CommandBot
  def self.running
    return $botrunning||false
  end

  def initialize()
    puts "Initializing..."
    @config = YAML.load_file('config.yaml') #Load a simple configuration file
    @locations = Array.new #Remember channels and roles we've created

    #This method initializes the underlying CommandBot and Bot classes and connects to the server
    super(
      application_id: @config['authentication']['appid'],
      token: @config['authentication']['token'],
      prefix: @config['commands']['prefix']
    )

    self.prepare
    $botrunning = true
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
      &method(:command_reload)
    )
    self.command(
      :selfupdate,
      :max_args => 0,
      :usage => "!selfupdate",
      :permission_level => 10,
      &method(:command_selfupdate)
    )
    #Do setup after connection to server is complete
    self.ready {
      @config['authentication']['admins'].each { |entry|
        self.set_user_permission(entry, 10)
        self.users[entry].pm("Jibril bot is now online") if self.users[entry]
      }
    }
  end

  def finalize()
    puts "Cleaning up"
    @locations.map!(&:finalize) #Call finalize on all locations
    @locations = Array.new #Makes all old instances eligible for GC
  end

  def command_goto(event, name)
    channelname = "#{@config['commands']['goto']['prefix']}#{name}"
    rolename = "Roleplaying in #{name}"

    begin
      #Create a Location object and add it to our list of tracked locations
      @locations.push(Location.new(event.server, channelname, rolename))
      event.respond "Done! Head on over to ##{channelname}"
    rescue
      event.respond "Sorry, I couldn't create the location for you."
    end
  end

  def command_reload(event, *args)
    begin
      is_hard = args[0] =~ /y|yes|1|true|hard/
      self.finalize()
      if is_hard
        Process.reload
      else
        self.commands.each_value { |c| self.remove_command(c.name) }
        load $0
        self.prepare
        event.respond "Done! :heart:" if event
      end
    rescue
      Process.reload #Fall back to hard reset
    end
  end

  def command_selfupdate(event)
    exec("git pull")
    self.command_restart(event)
  end
end
