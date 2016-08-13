class Jibril < Discordrb::Commands::CommandBot
  def version; "1.0.0"; end

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
    puts "Defining commands..."

    #Register all of the bot's available commands; note that method() is used to
    #pass instance methods as blocks for these definitions
    self.command(
      :open,
      :min_args => 1,
      :max_args => 1,
      :usage => "#{@config['commands']['open']['prefix']}open <name>",
      &method(:command_open)
    )
    self.command(
      :join,
      :min_args => 1,
      :max_args => 1,
      :usage => "#{@config['commands']['open']['prefix']}join <name>",
      &method(:command_join)
    )
    self.command(
      :close,
      :min_args => 1,
      :max_args => 1,
      :usage => "#{@config['commands']['open']['prefix']}close <name>",
      &method(:command_close)
    )
    self.command(
      :reload,
      :min_args => 0,
      :max_args => 1,
      :usage => "#{@config['commands']['open']['prefix']}reload [hard?]",
      :permission_level => 10,
      &method(:command_reload)
    )
    self.command(
      :selfupdate,
      :usage => "#{@config['commands']['open']['prefix']}selfupdate",
      :permission_level => 10,
      &method(:command_selfupdate)
    )
    self.command(:version) { "Jibril bot version #{self.version}" }

    #Do setup after connection to server is complete
    self.ready {
      @config['authentication']['admins'].each { |id|
        self.set_user_permission(id, 10)
        self.users[id].pm("Jibril bot is now online") if self.users[id]
      }
    }
  end

  def finalize()
    puts "Cleaning up"
    @locations.map!(&:finalize) #Call finalize on all locations
    @locations = Array.new #Makes all old instances eligible for GC
  end

  protected

  def message_admin(message)
    begin
      puts "--admin-- #{message}"
      @config['authentication']['admins'].each { |id|
        self.users[id].pm(message) if self.users[id]
      }
    rescue
      puts "Failed to send admin message: #{$!.message} (#{$!.backtrace[0]})"
    end
  end

  def command_open(event, name)
    channelname = "#{@config['commands']['open']['prefix']}#{name.downcase}"
    rolename = "Roleplaying in #{name}"

    #Sanity checks
    return "Name is too long!" if name.length > 8
    return "Invalid name!" if name !~ /^[a-zA-Z0-9]+$/

    begin
      event.message.delete
      newlocation = Location.new(event.server, channelname, rolename) {
        event.user.on(event.server).add_role(newlocation.role)
        event.respond "#{newlocation.channel.mention} is now open"
      }
      @locations.push(newlocation)
      nil #Prevent Discordrb from sending a string representation of the object
    rescue
      @locations.delete newlocation if newlocation
      event.respond "Sorry, I couldn't create '#{name}'"
      raise $!, "Failed to create location: #{$!}", $!.backtrace #
    end
  end

  def custom_channel_op(name, &block)
    #Get a list of locations with matching channel name
    matches = @locations.collect { |l| l.channel.name =~ /#{@config['commands']['open']['prefix']}#{name}/ ? l : nil }

    #Early outs
    return "Could not find that location!" if matches.length < 1
    return "Found multiple locations matching that name, please be more specific!" if matches.length > 1

    return yield matches[0]
  end

  def command_join(event, name)
    custom_channel_op(name) { |location|
      event.user.on(event.server).add_role(location.role)
      event.message.delete
      return "#{event.user.name} joined #{location.channel.mention}"
    }
  end

  def command_close(event, name)
    custom_channel_op(name) { |location|
      @locations.delete(location)
      location.finalize()
      event.message.delete
      return "##{location.channel.name} is now closed"
    }
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
    begin
      exec("git pull --ff-only") #Pull but fast forward only
      self.command_restart(event, 'hard') #Transform into a reload command
    rescue
      raise $!, "Failed to self update: #{$!}", $!.backtrace
    end
  end

  #Alias the old method so we can reference it below.
  #Unless ensures we don't alias our alias on hot reload and cause stack overflow
  (alias_method :default_command, :command) unless Jibril.instance_methods.include? :default_command
  def command(name, attributes = {}, &block)
    #Overload the command method to wrap each block in a safety net
    default_command(name, attributes) { |*args| #Capture any command parameters
      begin
        yield *args #Proceed as normal, passing along any parameters
      rescue Exception => e
        #Something went horribly wrong
        message_admin("Internal error: `#{e.message.gsub('`', "'")} (#{e.backtrace[0].gsub('`', "'")})`")
        return "Sorry, something went wrong"
      end
    }
  end
end
