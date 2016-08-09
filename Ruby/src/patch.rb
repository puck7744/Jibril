#Monkey patch Process because why not
module Process
  def self.reload()
    exec("ruby #{__FILE__}", *ARGV)
  end
end

#Patch method to match default_channel
class Discordrb::Server
  def default_role
    self.role(@id)
  end
end
