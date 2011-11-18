Installation
------------

- Edit `autotm.conf.sample` to match your setup
- Copy files:

    `sudo cp autotm.rb /usr/local/bin/autotm`

    `sudo cp de.abstracture.autotm.plist /Library/LaunchDaemons/`
    
    `sudo cp autotm.conf.sample /etc/autotm.conf`
    
    `sudo chmod 0600 /etc/autotm.conf`

- Load the daemon (needs to be run only once):

    `sudo launchctl load /Library/LaunchDaemons/de.abstracture.autotm.plist`

### Config file

The config file is in yaml format and contains configurations for available destinations using the following keys:

 - type (remote | local)
 - volume (only for local)
 - hostname (only for remote)
 - username (only for remote)
 - password (only for remote)
 - path (optional for remote, default is '/Backups')

The sample file should hopefully be self-explanatory with respect to file format.

Some notes regarding actual values:

Local destinations (essentially usb or firewire disks) only need one key: the path to the volume. This is typically "/Volume/<Volume Name>" where <Volume Name> is the volume's name as shown in the Finder. Note that you don't need to quote the name should it contain blanks. It will be handled automatically.

The default for the optional remote path is `/Backups`, which is what OSX Lion Server uses as a name for its time machine share. This may vary depending on your setup.

The easiest way to determine your backup configuration for remote backups is to grep through your system.log:

`grep backupd /var/log/system.log | grep "Mounted network"`

This will show you the used URL:

`Sep 20 02:16:14 Thebe com.apple.backupd[92971]: Mounted network destination at mountpoint: /Volumes/Backups using URL: afp://jdoe@mymac.local/Backups`

This would translate to:

 - type: remote
 - hostname: mymac.local
 - username: jdoe
 - path: /Backups

in your config file (where path is optional).

### Logging

In order to monitor what `autotm` is doing, the LaunchDaemon is configured to log to `/var/log/autotm.log`. You can inspect this file through the console to confirm everything is working as expected.

### Server Selection Logic

A few notes about how servers are selected:

 - `autotm` looks at your system.log to determine if the last backup failed
 - if it failed, `autotm` will go through the list of configured destinations to look for an alternative
 - multiple available destinations will get prioritized in the following order:
   - choose local destinations first (in order listed)
   - if multiple remote destinations are available (i.e. respond to pings), `autotm` will pick the fastest one (your office server may be visible via a presumably slower VPN connection for example but you want to avoid backing up there from home)
 - if your last backup was successful but the destination is not available anymore `autotm` will check for alternatives and pick the 'best' one, as described above
