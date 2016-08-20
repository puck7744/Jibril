class Jibril
  def command_reload(event, *args)
    begin
      is_hard = args[0] =~ /y|yes|1|true|hard|full/
      self.finalize()
      if is_hard
        Process.reload
      else
        self.commands.each_value { |c| self.remove_command(c.name) }
        load $0
        self.load_users()
        self.prepare()
        event.respond "Done! :heart:" if event
      end
    rescue
      Process.reload #Fall back to hard reset
    end
  end

  def command_selfupdate(event)
    begin
      exec("git pull --ff-only") #Pull but fast forward only
      self.command_reload(event, 'hard') #Transform into a reload command
    rescue
      raise $!, "Failed to self update: #{$!}", $!.backtrace
    end
  end

  def command_version(event)
    "Jibril bot version #{self.version}"
  end
end
