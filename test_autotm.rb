require 'test/unit'
require 'fileutils'
require 'autotm'

include Autotm

TEST_DIR = '/tmp/test dir'

def get_conf
  YAML.load(%{
destinations:
 - type: remote
   hostname: localhost
   username: jdoe
   password: s3cr3t
 - type: remote
   hostname: www.google.com
   username: john_doe
   password: pa55 
 - type: remote
   hostname: does.not.exist
   username: john_doe
   password: pa55 
 - type: local
   volume: /tmp/test dir
   })
end


class File
  def self.set_log(log)
    @@log = log
  end
  
  def self.read(fname)
    @@log
  end
end


$action = nil

def start_backup(tm_dest)
  $action = "sudo tmutil setdestination #{tm_dest}"
end


class TestAutotm < Test::Unit::TestCase

  def setup
    FileUtils.mkdir(TEST_DIR)
  end


  def teardown
    FileUtils.rmdir(TEST_DIR)
  end
  

  def test_01_ping
    res = ping('localhost')
    assert(res > 0)
  end


  def test_02_get_available_destinations
    dest = get_available_destinations()
    assert_equal(3, dest.size)
    # localhost should always be quicker than google.com
    assert_equal('/tmp/test dir', dest[0]['volume'])
    assert_equal('localhost', dest[1]['hostname'])
    assert_equal('www.google.com', dest[2]['hostname'])
  end


  def test_03_tm_events
    File.set_log(%{Nov 13 12:10:02 Localhost com.apple.backupd[29592]: NAConnectToServerSync failed with error: 64 for url: afp://jdoe@localhost/Backups
Nov 13 18:56:46 Localhost com.apple.backupd[30921]: Mounted network destination at mountpoint: /Volumes/Backups using URL: afp://jdoe@localhost/Backups})
    evts = get_tm_events
    assert_equal(2, evts.size)
    assert_equal([:failure, "afp://jdoe@localhost/Backups"], evts[0])
    assert_equal([:success, "afp://jdoe@localhost/Backups"], evts[1])
  end


  def test_03_tm_events_local_disk_failure
    File.set_log(%{08/11/2011 09:36:30.454 com.apple.backupd: Starting standard backup
08/11/2011 09:36:43.398 com.apple.backupd: Error -35 while resolving alias to backup target
08/11/2011 09:36:56.372 com.apple.backupd: Backup failed with error: 19})
    evts = get_tm_events
    assert_equal(1, evts.size)
    assert_equal([:failure, nil], evts[0])
  end


  def test_03_tm_events_local_disk_success
    File.set_log(%{08/11/2011 09:37:19.946 com.apple.backupd: Starting standard backup
08/11/2011 09:37:25.034 com.apple.backupd: Backing up to: /Volumes/Time Machine/Backups.backupdb
08/11/2011 09:39:56.259 com.apple.backupd: 3.98 GB required (including padding), 119.28 GB available
08/11/2011 09:42:11.810 com.apple.backupd: Copied 20856 files (730.0 MB) from volume osprey HD.
08/11/2011 09:42:27.405 com.apple.backupd: 3.13 GB required (including padding), 118.56 GB available
08/11/2011 09:42:46.375 com.apple.backupd: Copied 6714 files (57.8 MB) from volume osprey HD.
08/11/2011 09:42:53.997 com.apple.backupd: Starting post-backup thinning
08/11/2011 09:42:53.997 com.apple.backupd: No post-back up thinning needed: no expired backups exist
08/11/2011 09:42:54.593 com.apple.backupd: Backup completed successfully.})
    evts = get_tm_events
    assert_equal(1, evts.size)
    assert_equal([:success, "/Volumes/Time Machine"], evts[0])
  end


  def test_04_is_available
    url = 'afp://jdoe@localhost/Backups'
    assert(is_available(url))
    url = 'afp://jdoe@badhost/Backups'
    assert(! is_available(url))
    url = TEST_DIR
    assert(is_available(url))
    url = '/no/such/directory'
    assert(! is_available(url))
  end


  def test_05_run_backup
    $action = nil
    run_backup
    assert_equal(%{sudo tmutil setdestination "/tmp/test dir"}, $action)
  end


  def test_06_schedule_tm_backup
    $action = nil
    dest = get_available_destinations()
    assert_equal('/tmp/test dir', dest[0]['volume'])
    assert_equal('localhost', dest[1]['hostname'])
    schedule_tm_backup(dest[0])    
    assert_equal(%{sudo tmutil setdestination "/tmp/test dir"}, $action)
    schedule_tm_backup(dest[1])    
    assert_equal(%{sudo tmutil setdestination afp://jdoe:s3cr3t@localhost/Backups}, $action)
  end

end
