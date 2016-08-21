class Jibril < Discordrb::Commands::CommandBot
  def version; "1.2.1"; end

  def self.start()
    @@instance = Jibril.new unless defined? @@instance
  end

  def initialize()
    puts "Initializing..."

    @config = YAML::Store.new('config.yaml') #Load a simple configuration file
    @locations = Array.new #Remember channels and roles we've created
    @data = YAML::Store.new('data.yaml')

    #This method initializes the underlying CommandBot and Bot classes and connects to the server
    @config.transaction {
      super(
        application_id: @config[:authentication]['appid'],
        token: @config[:authentication]['token'],
        prefix: @config[:bot]['prefix']
      )
    }

    #Do setup after connection to server is complete
    self.ready {
      self.load_users()
    }

    self.prepare()
    self.run()
  end

  def prepare()
    #Register all of the bot's available commands; note that method() is used to
    #pass instance methods as blocks for these definitions
    puts "Loading commands..."

    @config.transaction {
      @config[:commands].each { |name, value|
        attributes = value.map { |k, v|
          case (k)
            when /min_args|max_args|permission_level/
              v = v.to_i
          end
          [k.to_sym, v]
        }.to_h
        self.command(
          name.to_sym,
          attributes,
          &method("command_#{name}".to_sym)
        )
      }
    }
  end

  def load_users()
    @config.transaction {
      @config[:authentication][:users].each { |id, level|
        self.set_user_permission(id, level)
        self.users[id].pm("Jibril bot is now online") if self.users[id] && level >= @config[:authentication][:levels]['admin']
      }
    }
  end

  protected

  def message_admin(message)
    begin
      puts "--admin-- #{message}"
      @config.transaction {
        @config[:authentication][:users].each { |id, level|
          self.users[id].pm(message) if self.users[id] && level >= @config[:authentication][:levels]['admin']
        }
      }
    rescue
      puts "Failed to send admin message: #{$!.message} (#{$!.backtrace[0]})"
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
