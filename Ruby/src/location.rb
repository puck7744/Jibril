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
