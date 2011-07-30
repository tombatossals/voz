#!/bin/bash
# HSMMN PBX Build and Setup Script
# v0.3.0 (C) Alex Casanova / Rodrigo de la Fuente / David Rubert
# HSMMN Project 2011
# vim: tabstop=4: shiftwidth=4: noexpandtab:
# kate: tab-width 4; indent-width 4; replace-tabs false;
#
#####################################################################
# Asterisk cron job generator

#####################################################################
# Copy the templates to the Asterisk configuration directory

echo "*********************************************"
echo "****** Asterisk cron job generator **********"
echo "*********************************************"
echo

while [ -z "$NODE_ID" ]; do
    echo "The node if of this URL 'http://guifi.net/node/40175' is '40175'"
    echo -n "Insert the node ID of your asterisk service on guifi.net: "
    read NODE_ID;
done

while [ -z "$PASSWORD" ]; do
    echo -n "Now, insert the password of the kamailio trunk of your asterisk service: "
    read PASSWORD;
done

MD5HASH=$(echo -n $PASSWORD|md5sum|cut -f1 -d" ")
URL="http://guifi.net/guifi/pabx/$NODE_ID/getcfg/$MD5HASH"

TMPFILE=$(mktemp)

sed -e s@'{{URL}}'@"$URL"@ cron.template > $TMPFILE
echo "Your cron script is located here: $TMPFILE"
echo "Move it to your cron jobs and schedule the execution every 10min."
