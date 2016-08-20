class Jibril
  protected
  def command_rules(event, *args)
    viapm = args[0] !~ /y|yes|true|1|public/ || event.channel.private?
    rulestext = String.new

    @data.transaction {
      (event.message.delete unless event.channel.private?) rescue nil;
      rulestext = @data.fetch(:rules, "`No rules defined!`")
    }

    viapm ? event.user.pm(rulestext) : event.respond(rulestext)
  end

  def command_setrules(event, *args)
    @data.transaction {
      (event.message.delete unless event.channel.private?) rescue nil;
      @data[:rules] = event.text.sub(/^#{self.prefix}#{event.command.name} /, '')
    }
    "Rules have been updated!"
  end
end
