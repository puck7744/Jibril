#Holds information about a channel and its associated role
class Location
  attr_reader :server, :channel, :role
  def initialize(server, name, role)
    begin
      #Create a custom channel and a role to view it
      @server = server
      @channel = @server.create_channel(name)
      @role = @server.create_role()
      @role.name = role
      @role.permissions = 0

      @channel.define_overwrite(@server.default_role, 0, 9007199254740991) #No permissions
      @channel.define_overwrite(@role.id, 67177472, 0)#Basic permissions
    rescue Exception => e
      puts e.message
      self.finalize()
      raise
    end
  end

  def finalize()
    @channel.delete if @channel
    @role.delete if @role
    @@running = false
  end
end
