class Jibril
  protected
  def command_open(event, name)
    channelname = rolename = newchannel = newrole = nil
    name.downcase!
    @config.transaction {
      channelname = (@config[:commands]['open']['channel']||'roleplay-%name%').gsub(/%name%/i, name)
      rolename = (@config[:commands]['open']['role']||'Roleplaying in %name%').gsub(/%name%/i, name.capitalize)
    }
    @data.transaction {
      #Initialize necessary data
      @data['channel_count'] = 0 unless @data['channel_count']
      @data[:channels] ||= {}
      @data[:channels][event.server.id] ||= {}
    }

    begin
      #Sanity checks
      return "Name is too long!" if name.length > 8
      return "Invalid name!" if name !~ /^[a-zA-Z0-9]+$/
      return "Too many channels active!" if @data.transaction { @data['channel_count'] > @config.transaction { @config[:commands]['open']['limit']||8 } }

      (event.message.delete) rescue nil

      #Listen for the channel to finish being created, then create a role for it
      event.server.await(:channelready, Discordrb::Events::ChannelCreateEvent, { :name => channelname }) {
        newchannel.define_overwrite(event.server.default_role, 0, 9007199254740991) #No permissions, should make the channel invisible?
        newrole = event.server.create_role()
        newrole.name = rolename
        newrole.permissions = 0
      }
      #Listen for the role to be created, then assign it to the channel
      event.server.await(:roleready, Discordrb::Events::ServerRoleCreateEvent, { :name => rolename }) {
        newchannel.define_overwrite(role, 67177472, 0) #Minimal permissions
        @data.transaction {
          @data[:channels][event.server.id][name] = {
            'channel' => newchannel.id,
            'role' => newrole.id
          }
          @data['channel_count'] += 1
        }
        event.respond "Done! Head on over to #{channel.mention}"
      }
      newchannel = event.server.create_channel(channelname) #create the channel
      nil #Prevent Discordrb from sending a string representation of the object
    rescue
      newchannel.delete if newchannel
      newrole.delete if newrole
      event.respond "Sorry, I couldn't create '#{name}'"
      raise $!, "Failed to create location: #{$!}", $!.backtrace #
    end
  end

  def command_join(event, name)
    custom_channel_op(name) { |location|
      event.user.on(event.server).add_role(location['role'])
      "#{event.user.name} joined #{location['channel'].mention}"
    }
  end

  def command_close(event, name)
    custom_channel_op(name) { |location|
      location.channel.delete
      location.role.delete
      "##{location.channel.name} is now closed"
    }
  end

  def custom_channel_op(event, name, &block)
    (event.message.delete) rescue nil

    #Get a list of locations with matching channel name
    matches = @data.transaction {
      return [] unless @data[:channels][event.server.id]
      return @data[:channels][event.server.id].collect { |l|
        return nil unless remote_chan = self.channel(l['channel'].to_i)
        return remote_chan.name =~ /#{@config.transaction { @config[:commands]['open']['prefix'] }}#{name}/i ? { :channel => remote_chan, :role => self.role(l['role'].to_i) } : nil
      }
    }

    #Early outs
    return "Could not find that location!" if matches.length < 1
    return "Found multiple locations matching that name, please be more specific!" if matches.length > 1

    return yield matches[0]
  end
end
