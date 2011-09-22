Installation
------------

- Edit `autotm.conf.sample` to match your setup
- Copy files:

    `sudo cp autotm /usr/local/bin/`

    `sudo cp de.abstracture.autotm.plist /Library/LaunchDaemons/`
    
    `sudo cp autotm.conf.sample /etc/autotm.conf`

- Load the daemon (needs to be run only once):

    `launchctl load /Library/LaunchDaemons/de.abstracture.autotm.plist`

### Config file

The config file is in yaml format and contains the following keys:

 - hostname
 - username
 - password
 - path (optional)

The default for the path is `/Backups`, which is what OSX Lion Server uses as a name for its time machine share. This may vary depending on your setup.

The easiest way to determine your backup configuration is to grep through your system.log:

`grep backupd /var/log/system.log | grep "Mounted network"`

This will show you the used URL:

`Sep 20 02:16:14 Thebe com.apple.backupd[92971]: Mounted network destination at mountpoint: /Volumes/Backups using URL: afp://jdoe@mymac.local/Backups`

This would translate to:

 - hostname: mymac.local
 - username: jdoe
 - path: /Backups

in your config file.

### Logging

In order to monitor what `autotm` is doing, the LaunchDaemon is configured to log to `/var/log/autotm.log`. You can inspect this file through the console confirm everything is working as expected.

### Server Selection Logic

A few notes about how servers are selected:

 - `autotm` looks at your system.log to determine if the last backup failed
 - if it failed, `autotm` will go through the list of configured servers to look for an alternative
 - if multiple servers respond to pings, `autotm` will pick the fastest one (your office server may be visible via a presumably slower VPN connection for example but you want to avoid backing up there from home)
 - if your last backup was successful but the server is not available anymore `autotm` will check for alternatives and pick the fastest one, as described above
