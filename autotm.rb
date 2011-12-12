#!/usr/bin/ruby

require 'yaml'
require 'time'

module Autotm

  CONF_FILE = '/etc/autotm.conf'
  
  def get_conf
    # conf file format: see autotm.conf.sample
  
    conf_file = File.expand_path(CONF_FILE)
    
    if File.exist?(conf_file)
      conf = YAML.load(File.read(conf_file))
    else
      raise Exception.new("Configuration file is missing.")
    end
    
    conf
  end
  
  
  def ping(hostname)
    res = %x[ping -q -c 1 #{hostname} 2>&1]
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
    if destinations == nil
      puts "#{Time.now}: ERROR: No destinations defined in conf file. Exiting."
      exit!(-1)
    end
    
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
    
    network_connection_failed = \
      /NAConnectToServerSync failed with error: 64 for url: (\S+)/
    mounted_network_destination = \
      /Mounted network destination at mountpoint: \S+ using URL: (\S+)/
    backup_failed = /Backup failed with error: (\d+)/
    backing_up_to_dir = /Backing up to: (.+)\/Backups.backupd/
    
    last_match = nil
    
    File.read('/var/log/system.log').each do |line|
      if line =~ /com.apple.backupd/
        if line =~ network_connection_failed
          url = $1
          events << [:failure, "#{url}"]
          last_match = line
        end
        
        if line =~ mounted_network_destination
          url = $1
          events << [:success, "#{url}"]
          last_match = line
        end
        
        if line =~ backup_failed
          events << [:failure, nil]
          last_match = line
        end
        
        if line =~ backing_up_to_dir
          disk = $1
          if not last_match =~ mounted_network_destination
            events << [:success , "#{disk}"]
            last_match = line
          end
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
  
  
  def start_backup(tm_dest)
    %x[sudo tmutil setdestination #{tm_dest}]
    sleep(5)
    %x[tmutil startbackup]
  end
  
  
  def schedule_tm_backup(dest)
    if dest['type'] == 'remote'
      user = dest['username']
      hostname = dest['hostname']
      password = dest['password']
      path = dest['path'] || '/Backups'
      tm_dest = "afp://#{user}:#{password}@#{hostname}#{path}"
      puts "#{Time.now}: Backing up to: afp://#{user}@#{hostname}#{path}"
    else
      tm_dest = %{"#{dest['volume']}"}
      puts "#{Time.now}: Backing up to: #{tm_dest}"
    end    
    start_backup(tm_dest)
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


  def requires_ac_power?
    plist = '/Library/Preferences/com.apple.TimeMachine'
    res = %x[defaults read #{plist} RequiresACPower 2>&1]
    return Integer(res) == 1
  end


  def on_ac_power?
    res = %x[pmset -g batt 2>&1]
    res.each do |line|
      # looking for strings in output -- works on localised systems
      # (tested: it is still in English even on a German language 
      # system)
      if line =~ /'AC Power'/
        return true
      end
      if line =~/'Battery Power'/
        return false
      end
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
