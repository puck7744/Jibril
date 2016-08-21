class Jibril
  def command_reload(event, *args)
    Process.reload
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
