Installation
---------

 - edit /etc/autotm.conf to match your setup
 - copy files:

  > sudo cp autotm /usr/local/bin/

  > sudo cp de.abstracture.autotm.plist /Library/LaunchDaemons/ 

  > sudo cp autotm.conf.sample /etc/autotm.conf

 - load the daemon (needs to be run only once):

  > launchctl load /Library/LaunchDaemons/de.abstracture.autotm.plist