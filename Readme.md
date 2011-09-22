Installation
---------

1. Edit ```autotm.conf.sample``` to match your setup
2. Copy files:

  ```sudo cp autotm /usr/local/bin/
  sudo cp de.abstracture.autotm.plist /Library/LaunchDaemons/ 
  sudo cp autotm.conf.sample /etc/autotm.conf
  ```

3. Load the daemon (needs to be run only once):

  ```launchctl load /Library/LaunchDaemons/de.abstracture.autotm.plist```
