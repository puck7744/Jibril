class Jibril < Discordrb::Commands::CommandBot
  def version; "1.0.7"; end

  def self.running
    return $botrunning||false
  end

  def initialize()
    puts "Initializing..."
    @config = YAML.load_file('config.yaml') #Load a simple configuration file
    @locations = Array.new #Remember channels and roles we've created
    @data = YAML::Store.new('data.yaml')

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

    ### Roleplay Commands ###
    self.command(
      :rules,
      max_args: 0,
      description: 'Get a copy of the roleplaying rules delivered via DM',
      usage: "#{@config['commands']['prefix']}rules",
      &method(:command_rules)
    )
    self.command(
      :setrules,
      min_args: 1,
      description: "Set the message for #{@config['commands']['prefix']}rules",
      usage: "#{@config['commands']['prefix']}setrules",
      &method(:command_setrules)
    )

    ### Meta Commands ###
    self.command(
      :reload,
      min_args: 0,
      max_args: 1,
      description: 'Reloads Jibril in memory (soft) or from disk (hard)',
      usage: "#{@config['commands']['prefix']}reload [hard?]",
      permission_level: 10,
      &method(:command_reload)
    )
    self.command(
      :selfupdate,
      description: 'Updates Jibril to the latest version via Git.',
      usage: "#{@config['commands']['prefix']}selfupdate",
      permission_level: 10,
      &method(:command_selfupdate)
    )
    self.command(:version, description: 'Outputs the currently running version of Jibril',
    usage: "#{@config['commands']['prefix']}version") { "Jibril bot version #{self.version}" }

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

  def command_rules(event, *args)
    @data.transaction { event.respond @data.fetch(:rules, "`No rules defined!`") }
  end

  def command_setrules(event, *args)
    @data.transaction { @data[:rules] = args.join(' ').gsub('|', '\n') }
    "Rules have been updated!"
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
