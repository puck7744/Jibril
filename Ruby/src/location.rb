#Holds information about a channel and its associated role
class Location
  attr_reader :server, :channel, :role
  def initialize(server, channelname, rolename, &block)
    begin
      #Create a custom channel and a role to view it
      @server = server
      @server.await(:channelready, Discordrb::Events::ChannelCreateEvent, { :name => channelname}) {
        puts "Channel created"
        @role = @server.create_role()
        @role.name = rolename
        @role.permissions = 0
      }
      @server.await(:roleready, Discordrb::Events::ServerRoleCreateEvent, { :name => rolename }) {
        puts "Role created"
        @channel.define_overwrite(@server.default_role, 0, 9007199254740991) #No permissions
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
    begin
      @channel.delete if @channel
      @role.delete if @role
    rescue Exception => e
      puts "Could not delete channel or role for location #{@name}: #{e.message} (#{e.backtrace[0]})"
    end
  end
end
