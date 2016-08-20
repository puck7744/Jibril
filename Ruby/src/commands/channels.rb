#Holds information about a channel and its associated role
class Location
  attr_reader :server, :channel, :role
  def initialize(server, channelname, rolename, &block)
    begin
      #Create a custom channel and a role to view it
      @server = server

      #Listen for the channel to finish being created, then create a role for it
      @server.await(:channelready, Discordrb::Events::ChannelCreateEvent, { :name => channelname}) {
        @channel.define_overwrite(@server.default_role, 0, 9007199254740991) #No permissions, should make the channel invisible?
        @role = @server.create_role()
        @role.name = rolename
        @role.permissions = 0
      }
      #Listen for the role to be created, then assign it to the channel
      @server.await(:roleready, Discordrb::Events::ServerRoleCreateEvent, { :name => rolename }) {
        @channel.define_overwrite(@role, 67177472, 0) #Minimal permissions
        yield @channel, @role
      }
      @channel = @server.create_channel(channelname)
    rescue Exception => e
      self.finalize()
      raise
    end
  end

  def finalize()
    #Make sure we don't leave any garbage
    @channel.delete if @channel
    @role.delete if @role
  end
end

class Jibril
  protected
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

  def custom_channel_op(name, &block)
    #Get a list of locations with matching channel name
    matches = @locations.collect { |l| l.channel.name =~ /#{@config['commands']['open']['prefix']}#{name}/ ? l : nil }

    #Early outs
    return "Could not find that location!" if matches.length < 1
    return "Found multiple locations matching that name, please be more specific!" if matches.length > 1

    return yield matches[0]
  end
end
