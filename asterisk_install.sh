#!/bin/bash
# HSMMN PBX Build and Setup Script
# v0.3.0 (C) Alex Casanova / Rodrigo de la Fuente / David Rubert
# HSMMN Project 2011
# vim: tabstop=4: shiftwidth=4: noexpandtab:
# kate: tab-width 4; indent-width 4; replace-tabs false;
#

#####################################################################
# Compilation and installation DIR. Applications version

ASTERISK_VERSION=1.8.5.0
DAHDI_VERSION=2.4.1.2+2.4.1
LIBPRI_VERSION=1.4.12
ADDONS_VERSION=1.6.2.4

COMPILE_DIR=/opt/asterisk/src
INSTALL_DIR=/opt/asterisk

#####################################################################
# Raise the error message and exit

function raise() {
    [ -f $ASTERISK_COMPILE_DIR/compile.log ] && tail -15 $ASTERISK_COMPILE_DIR/compile.log
    exit -1
}

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
# Check for the necessary directories and libraries

echo "***************************************"
echo "****** Asterisk installation **********"
echo "***************************************"
echo

[ ! -d "$INSTALL_DIR" ] && echo "Installation dir $INSTALL_DIR not found." && exit -1
[ ! -d "$COMPILE_DIR" ] && echo "Compilation dir $COMPILE_DIR not found." && exit -2

# Create the compilation directory for this execution
mkdir -p $COMPILE_DIR/asterisk-`date +%F_%H-%M-%S`
ASTERISK_COMPILE_DIR=$COMPILE_DIR/asterisk-`date +%F_%H-%M-%S`

# If our system is Debian or Ubuntu, check for the necessary development packages 
which aptitude > /dev/null
if [ $? = 0 ]; then
    echo "** You are using Debian or Ubuntu, we are going to test for the development packages..."
    if [ "$(dpkg -l build-essential linux-headers-`uname -r` libncurses5-dev libmysqlclient-dev libxml2-dev | grep -E "^ii  " | wc -l)" -ne "5" ]; then
        echo "* We need to install some development packages for you. Please enter root password"
        sudo aptitude install -y build-essential linux-headers-`uname -r` libncurses5-dev libmysqlclient15-dev libxml2-dev
    fi
    echo "* Done"
    echo
fi


#####################################################################
# Create the main compilation directories

echo "** We are going to download, extract, compile and install the asterisk framework on these directories:"
echo "* Installation dir: $INSTALL_DIR"
echo "* Compilation dir: $COMPILE_DIR"
echo
echo "But first, we need to ask some questions to you."
echo
echo "** Optional packages **"
if yesno --default no "Download, compile, and install libpri: yes or no (default no)? "; then
	LIBPRI=yes
fi

if yesno --default no "Download, compile, and install dahdi: yes or no (default no)? "; then
	DAHDI=yes
fi

if yesno --default no "Download, compile, and install asterisk-addons: yes or no (default no)? "; then
	ADDONS=yes
fi


#####################################################################
# libpri optional installation

if [ ! -z $LIBPRI ]; then
	echo
	echo "** LIBPRI (2 minutes installation approx.) **"
	echo "* Retrieving packages..."
	wget -q -O - http://downloads.asterisk.org/pub/telephony/libpri/releases/libpri-$LIBPRI_VERSION.tar.gz | tar zx -C $ASTERISK_COMPILE_DIR

	echo "* Compiling packages..."
	cd $ASTERISK_COMPILE_DIR/libpri-$LIBPRI_VERSION
	make >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	echo "* Installing packages..."
	make install DESTDIR=$INSTALL_DIR >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	echo "* Done."
fi


#####################################################################
# Dahdi optional installation


if [ ! -z $DAHDI ]; then
	echo
	echo "** DAHDI (5 minutes installation approx.) **"
	echo "** We need to sudo root to install the kernel module, so you will be asked to enter the root password."
	echo "* Retrieving packages..."
	wget -q -O - http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/releases/dahdi-linux-complete-$DAHDI_VERSION.tar.gz | tar zx -C $ASTERISK_COMPILE_DIR
	echo "* Compiling packages..."
	cd $ASTERISK_COMPILE_DIR/dahdi-linux-complete-$DAHDI_VERSION
	make >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise

	echo "* Installing packages..."
	sudo make install >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	make config >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	make samples >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	echo "* Done."
fi


#####################################################################
# Asterisk installation

echo
echo "** Asterisk (15 minutes installation approx.) **"
echo "* Retrieving packages..."
wget -q -O - http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-$ASTERISK_VERSION.tar.gz | tar zx -C $ASTERISK_COMPILE_DIR

echo "* Compiling packages..."
cd $ASTERISK_COMPILE_DIR/asterisk-$ASTERISK_VERSION
OPTS=""
if [ ! -z $LIBPRI ]; then
    OPTS=" --with-pri=$INSTALL_DIR"
fi

if [ ! -z $DAHDI ]; then
    OPTS=" --with-dahdi=$INSTALL_DIR"
fi

./configure --prefix=$INSTALL_DIR $OPTS >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise

make >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
echo "* Installing packages..."
make install >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
#make config >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
make samples >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
echo "* Done."

#####################################################################
# Asterisk ADDONS optional installation

if [ ! -z $ADDONS ]; then
    echo "Asterisk Addons"
    echo "* Retrieving packages..."
	wget -q -O - http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-addons-$ADDONS_VERSION.tar.gz | tar zx -C $ASTERISK_COMPILE_DIR
    echo "* Compiling packages..."
	cd $ASTERISK_COMPILE_DIR/asterisk-addons-$ADDONS_VERSION
	./configure --prefix=$INSTALL_DIR --with-asterisk=$INSTALL_DIR --includedir=$INSTALl_DIR/include >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	make >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	make install >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	make config >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	make samples >> $ASTERISK_COMPILE_DIR/compile.log 2>&1 || raise
	cd ..
fi


#####################################################################
# Additional codecs installation
#                          

echo
echo "** Addition Codec Installation **"
# Codec G729
echo "* Installing G.729 codec"
wget -q -O $INSTALL_DIR/lib/asterisk/modules/codec_g729-ast18-gcc4-glibc-pentium.so http://asterisk.hosting.lv/bin/codec_g729-ast18-gcc4-glibc-pentium.so

# Codec G723
echo "* Installing G.723 codec"
wget -q -O $INSTALL_DIR/lib/asterisk/modules/codec_g723-ast18-gcc4-glibc-pentium.so http://asterisk.hosting.lv/bin/codec_g723-ast18-gcc4-glibc-pentium.so
echo "* Done." 

#####################################################################
# Spanish voices installation
# Descargando el conjunto de voces en espanyol de Alberto Sagredo esta descarga varia en funcion de la conexion de Internet que tenga el equipo, aproximadamente descargando >50MB

echo
echo "** Spanish Sounds Installation **"
echo "* Downloading..."
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-g729-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-alaw-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-ulaw-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-gsm-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-g729-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-alaw-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-ulaw-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-gsm-1.4.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds
wget -q -O - http://www.voipnovatos.es/voces/asterisk-voces-es-v1_2-moh-voipnovatos.tar.gz | tar zx -C $INSTALL_DIR/var/lib/asterisk/sounds

echo "* Finished."
