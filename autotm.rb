#!/usr/bin/ruby

require 'yaml'
require 'time'

module Autotm

  CONF_FILE = '/etc/autotm.conf'
  
  def get_conf
    ## conf file format:
    # servers:
    #  - hostname: myhost.local
    #    username: myusername
    #    password: mypassword
    # -----------------------
    # optionally add (defaults to /Backup):
    #    path: /mypath
    # -----------------------
    # Entries will be assembled to the following backup url:
    #  "afp://#{user}:#{password}@#{hostname}#{path}"
  
    conf_file = File.expand_path(CONF_FILE)
    
    if File.exist?(conf_file)
      conf = YAML.load(File.read(conf_file))
    else
      raise Exception.new("Configuration file is missing.")
    end
    
    conf
  end
  
  
  def ping(hostname)
    res = %x[ping -q -c 10 -t 1 #{hostname} 2>&1]
    if $?.exitstatus == 0
      res.each do |line|
        if line =~ /^round-trip min\/avg\/max\/stddev = ([\d\.]+)/
          return $1.to_f
        end
      end
    else
      return 0
    end
  end
  
  
  def get_available_destinations
    available = []
    destinations = get_conf['destinations']
    
    destinations.each do |dest|
      if dest['type'] == 'remote'
        hostname = dest['hostname']
        time = ping(hostname)
        if time > 0
          dest['priority'] = time
          available << dest
        end
      else
        if File.directory?(dest['volume'])
          # give local destinations priority 0 so they get chosen over network
          # destinations
          dest['priority'] = 0
          available << dest
        end
      end
    end
    available = available.sort {|a,b| a['priority'] <=> b['priority']}
  end
  
  
  
  def get_tm_events
    events = []
    
    File.read('/var/log/system.log').each do |line|
      if line =~ /com.apple.backupd/
        if line =~ /NAConnectToServerSync failed with error: 64 for url: (\S+)/
          url = $1
          events << [:failure, "#{url}"]
        end
        
        if line =~ /Mounted network destination at mountpoint: \S+ using URL: (\S+)/
          url = $1
          events << [:success, "#{url}"]
        end
        
        if line =~ /Backup failed with error: (\d+)/
          events << [:failure, nil]
        end
        
        if line =~ /Backing up to: (.+)\/Backups.backupd/
          disk = $1
          events << [:success , "#{disk}"]
        end
      end
    end
      
    events
  end
  
  
  def is_available(url)
    # check if url is available
    if url.start_with?('/')
      # shortcut: just check for the path if the url starts with a "/"
      return File.directory?(url)
    else
      # otherwise ping all configured servers and check if the url includes
      # one of the available server names
      # doing it this way rather than parsing the server name from the url and
      # pinging that avoids the whole parsing hassle
      get_available_destinations.each do |dest|
        if dest['type'] == 'remote'
          hostname = dest['hostname']
          if url.include?(hostname)
            return true
          end
        end
      end
    end
    return false
  end
  
  
  def schedule_tm_backup(server)
    user = server['username']
    hostname = server['hostname']
    password = server['password']
    path = server['path'] || '/Backups'
    tm_url = "afp://#{user}:#{password}@#{hostname}#{path}"
    puts "#{Time.now}: Backing up to: afp://#{user}@#{hostname}#{path}"
    
    %x[sudo tmutil setdestination #{tm_url}]
    sleep(5)
    %x[tmutil startbackup]
  end
  
  
  def run_backup
    available = get_available_destinations
    
    if available.size > 0
      # servers are ordered by ping time, take fastest one
      # (prevents backing up to alternatives available via WAN)
      dest = available[0]
      schedule_tm_backup(dest)
    else
      puts "#{Time.now}: No time machine server found"
    end
  end

end # module


if __FILE__ == $0
  include Autotm
  
  events = get_tm_events
  
  if events == []
    puts "#{Time.now}: No backup events found (can happen after syslog roll at midnight)"
    return
  end
  
  last_status, last_url = events[-1]
  if last_status == :failure
    puts "#{Time.now}: Last backup failed, trying available servers"
    run_backup
  else # :success
    if not is_available(last_url)
      puts "#{Time.now}: Last used TM not available, trying configured alternatives"
      run_backup
    else
      puts "#{Time.now}: No action required: Last backup successful and TM available"
    end
  end
end
