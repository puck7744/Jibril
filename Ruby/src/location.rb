#Holds information about a channel and its associated role
class Location
  attr_reader :name, :server, :channel, :role
  def initialize(server, name, rolename)
    begin
      puts "Creating location #{name}"
      #Create a custom channel and a role to view it
      @name = name
      @server = server
      @channel = @server.create_channel(@name)

      @server.await(:roleready, Discordrb::Events::ServerRoleCreateEvent, { :name => rolename }) {
        puts "Role created, executing..."
        @channel.define_overwrite(@server.default_role, 0, 9007199254740991) #No permissions
        @channel.define_overwrite(@role.id, 67177472, 0)#Basic permissions
      }
      @role = @server.create_role()
      @role.name = rolename
      @role.permissions = 0
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
      puts "Could not delete channel or role for location #{@name}: #{e.message}"
    end
  end
end
