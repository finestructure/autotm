require 'test/unit'
require 'fileutils'
require 'autotm'

include Autotm

TEST_DIR = '/tmp/test dir'

def get_conf
  {"servers"=>[
    {"username"=>"jdoe", "hostname"=>"localhost", "password"=>"s3cr3t"},
    {"username"=>"jdoe", "hostname"=>"www.google.com", "password"=>"s3cr3t"}
    ]
  }
end


class File
  def self.set_log(log)
    @@log = log
  end
  
  def self.read(fname)
    @@log
  end
end


$scheduled = nil

def schedule_tm_backup(server)
  $scheduled = server
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
    assert_equal(2, dest.size)
    # localhost should always be quicker than google.com
    assert_equal('localhost', dest[0]['hostname'])
    assert_equal('www.google.com', dest[1]['hostname'])
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
    $scheduled = nil
    run_backup
    assert_equal('localhost', $scheduled['hostname'])
  end

end
