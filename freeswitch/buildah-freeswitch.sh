#! /bin/bash

CON=$(buildah from debian:10)
echo "Building in $CON"

# yikes - there is so much work to do
# it's easier to put it in a script than to have
# a massive number of buildah run lines
cat > install-5000.sh <<EOF
#!/bin/bash
apt-get update && apt-get install -y gnupg2 wget lsb-release locales
wget -O - https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc | apt-key add -

echo "deb http://files.freeswitch.org/repo/deb/debian-release/ buster main" > /etc/apt/sources.list.d/freeswitch.list
echo "deb-src http://files.freeswitch.org/repo/deb/debian-release/ buster main" >> /etc/apt/sources.list.d/freeswitch.list

# you may want to populate /etc/freeswitch at this point.
# if /etc/freeswitch does not exist, the standard vanilla configuration is deployed
apt-get update && apt-get install -y freeswitch-meta-all

cp /lib/systemd/system/freeswitch.service /etc/systemd/system/freeswitch.service
sed -i s/^IO/#IO/ /etc/systemd/system/freeswitch.service

# FreeSWTICH needs sendmail, weird!?
rm /etc/rc[2345].d/S*sendmail
# Just to avoid some ugliness when sendmail starts...
# ..but we nuked it anyway 
sed -i /loginuid/s/required/optional/ /etc/pam.d/*
#ensure we have a UTF-8 locale
sed -i -e s/.*en_US.UTF-8/en_US.UTF-8/ -e s/.*en_SG.UTF-8/en_SG.UTF-8/ /etc/locale.gen
locale-gen
EOF

buildah copy $CON install-5000.sh /root/install-5000.sh
buildah run $CON bash /root/install-5000.sh

# buildah commit $CON freeswitch:1.10.2
# podman run --entrypoint '["/sbin/init"]' --env LANG=en_US.UTF-8 --cap-add=sys_nice freeswitch:1.10.2
# Debian's FreeSWITCH also tries to use IO scheduling policies...
# On the host system: ionice -p <FREESWITCH_PID> -c 1 -n 2
