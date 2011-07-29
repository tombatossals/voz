#!/bin/bash
# HSMMN PBX Build and Setup Script
# v0.3.0 (C) Alex Casanova / Rodrigo de la Fuente / David Rubert
# HSMMN Project 2011
# vim: tabstop=4: shiftwidth=4: noexpandtab:
# kate: tab-width 4; indent-width 4; replace-tabs false;
#
#####################################################################
# Asterisk configuration

[ -d /opt/asterisk/etc/asterisk ] && CONFIG_DIR=/opt/asterisk/etc/asterisk
[ -d /etc/asterisk ] && CONFIG_DIR=/etc/asterisk

[ ! -z "$CONFIG_DIR" ] || (echo "No asterisk installation found. Edit this script to configure the Asterisk installation PATH"; exit -1)

#####################################################################
# Print warning message.

function warning()
{
    echo "$*" >&2
}


#####################################################################
# Print error message and exit.

function error()
{
    echo "$*" >&2
    exit 1
}


#####################################################################
# Ask yesno question.
#
# Usage: yesno OPTIONS QUESTION
#
#   Options:
#     --timeout N    Timeout if no input seen in N seconds.
#     --default ANS  Use ANS as the default answer on timeout or
#                    if an empty answer is provided.
#
# Exit status is the answer.

function yesno()
{
    local ans
    local ok=0
    local timeout=0
    local default
    local t

    while [[ "$1" ]]
    do
        case "$1" in
        --default)
            shift
            default=$1
            if [[ ! "$default" ]]; then error "Missing default value"; fi
            t=$(tr '[:upper:]' '[:lower:]' <<<$default)

            if [[ "$t" != 'y'  &&  "$t" != 'yes'  &&  "$t" != 'n'  &&  "$t" != 'no' ]]; then
                error "Illegal default answer: $default"
            fi
            default=$t
            shift
            ;;

        --timeout)
            shift
            timeout=$1
            if [[ ! "$timeout" ]]; then error "Missing timeout value"; fi
            if [[ ! "$timeout" =~ ^[0-9][0-9]*$ ]]; then error "Illegal timeout value: $timeout"; fi
            shift
            ;;

        -*)
            error "Unrecognized option: $1"
            ;;

        *)
            break
            ;;
        esac
    done

    if [[ $timeout -ne 0  &&  ! "$default" ]]; then
        error "Non-zero timeout requires a default answer"
    fi

    if [[ ! "$*" ]]; then error "Missing question"; fi

    while [[ $ok -eq 0 ]]
    do
        if [[ $timeout -ne 0 ]]; then
            if ! read -t $timeout -p "$*" ans; then
                ans=$default
            else
                # Turn off timeout if answer entered.
                timeout=0
                if [[ ! "$ans" ]]; then ans=$default; fi
            fi
        else
            read -p "$*" ans
            if [[ ! "$ans" ]]; then
                ans=$default
            else
                ans=$(tr '[:upper:]' '[:lower:]' <<<$ans)
            fi 
        fi

        if [[ "$ans" == 'y'  ||  "$ans" == 'yes'  ||  "$ans" == 'n'  ||  "$ans" == 'no' ]]; then
            ok=1
        fi

        if [[ $ok -eq 0 ]]; then warning "Valid answers are: yes y no n"; fi
    done
    [[ "$ans" = "y" || "$ans" == "yes" ]]
}


#####################################################################
# Main execution

#####################################################################
# Copy the templates to the Asterisk configuration directory

echo "****************************************"
echo "****** Asterisk configuration **********"
echo "****************************************"
echo

[ ! -d "$CONFIG_DIR" ] && echo "Configuration dir $CONFIG_DIR not found." && exit -2

#####################################################################
# Create the main compilation directories

echo "** We are going to configure your asterisk installation to integrate with guifi.net federated Asterisk."
echo "** WARNING!!! This is going to overwrite your Asterisk configuration files."
echo "* Configuration dir: $CONFIG_DIR"
echo
echo "First of all, we need to ask some questions to you. These are important, please answer carefully."
echo "You must have your Asterisk PABX registered as a service on guifi.net, and the Kamailio trunk must be approved by a Kamailio administrator."
echo "Read this document if you haven't done it yet: http://es.wiki.guifi.net/wiki/Asterisks_federados:_Administrador_Asterisk"
if ! yesno "Do you understand the pre-requisites? "; then
    echo "Ok, bye."
    exit -1
fi
echo "Ok, let's go on."
while [ -z "$KAMAILIO_USERNAME" ]; do 
    echo -n "Assigned kamailio username: "
    read KAMAILIO_USERNAME; 
done
while [ -z "$KAMAILIO_PASSWORD" ]; do 
    echo -n "Assigned kamailio password: "
    read KAMAILIO_PASSWORD; 
done
while [ -z "$PREFIX" ]; do 
    echo -n "Assigned prefix (example: 701201XXX): "
    read PREFIX; 
done
while [ -z "$FQDN" ]; do 
    echo -n "The FQDN (hostname) of your asterisk server: "
    read FQDN; 
done
while [ -z "$LOCALNET" ]; do 
    echo -n "The LOCALNET parameter of your network (example: 10.0.0.0/8): "
    read LOCALNET; 
done
if yesno "Backup your actual Asterisk configuration directory? "; then
  BACKUP_DIR=$CONFIG_DIR.$(date +"%Y-%m-%d")
  C=0
  while [ -e $BACKUP_DIR ]; do
      BACKUP_DIR=$BACKUP_DIR.$C
      C=$(expr $C + 1)
  done
  echo -n "Backing up $CONFIG_DIR to $BACKUP_DIR..."
  cp -Rp $CONFIG_DIR $BACKUP_DIR
  echo "ok."
fi
echo -n "Copying configuration files to asterisk..."
for F in etc/*
do
    cp -p $F $CONFIG_DIR/$(basename $F)
done
PABX_SUF=${PREFIX: -4}
PABXID=${PREFIX:0:5}
sed -i s/"{{USERNAME}}"/"$KAMAILIO_USERNAME"/g $CONFIG_DIR/sip.trunk.conf
sed -i s/"{{PASSWORD}}"/"$KAMAILIO_PASSWORD"/g $CONFIG_DIR/sip.trunk.conf
sed -i s/"{{FQDN}}"/"$FQDN"/g $CONFIG_DIR/sip.conf
sed -i s@"{{LOCALNET}}"@"$LOCALNET"@g $CONFIG_DIR/sip.conf
sed -i s/"{{PABXID}}"/"$PABXID"/g $CONFIG_DIR/extensions.conf
sed -i s/"{{PABX_SUF}}"/"$PABX_SUF"/g $CONFIG_DIR/extensions.conf
echo "done!"
