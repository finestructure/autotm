= Installation =

sudo cp autotm /usr/local/bin/
sudo cp de.abstracture.autotm.plist /Library/LaunchDaemons/
sudo cp autotm.conf.sample /etc/autotm.conf

Edit /etc/autotm.conf to match your setup.

launchctl load /Library/LaunchDaemons/de.abstracture.autotm.plist
