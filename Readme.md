Installation
------------

- Edit `autotm.conf.sample` to match your setup
- Copy files:

    `sudo cp autotm /usr/local/bin/`
    `sudo cp de.abstracture.autotm.plist /Library/LaunchDaemons/ `
    `sudo cp autotm.conf.sample /etc/autotm.conf`

- Load the daemon (needs to be run only once):

    `launchctl load /Library/LaunchDaemons/de.abstracture.autotm.plist`
