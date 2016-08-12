#Monkey patch Process because why not
module Process
  def self.reload()
    exec("ruby #{$0}", *ARGV)
  end
end

class Discordrb::Server
  #Patch method to match default_channel
  def default_role
    self.role(@id)
  end

  #Patch method to allow servers to await
  def await(key, type, attributes = {}, &block)
    #There doesn't seem to be a server attribute, so we hijack the block
    @bot.add_await(key, type, attributes) { |event|
      return false if event.server.id != @id
      yield
    }
  end
end

#Allow the setting of permission bits directly (https://github.com/meew0/discordrb/issues/177)
class Discordrb::Role
  def permissions=(p)
    self.packed = p #FIXME: This method is technically internal and may change
  end
end

#FIXME: This patch fixes an issue where event.name is used internally when it should be event.role.name
#       Remove when this issue is patched.
class Discordrb::Events::ServerRoleCreateEvent
  def name
    return @role.name
  end
end
