#!/opt/bin/bash
# HSMMN PBX Build and Setup Script
# v0.3.0 (C) Alex Casanova / Rodrigo de la Fuente
# HSMMN Project 2011
# vim: tabstop=4: shiftwidth=4: noexpandtab:
# kate: tab-width 4; indent-width 4; replace-tabs false;
#


#####################################################################
# Compilation and installation DIR. Applications version

COMPILE_DIR=/opt/asterisk/src
INSTALL_DIR=/opt/asterisk

ASTERISK_VERSION=1.8.2.3
DAHDI_VERSION=2.4.0+2.4.0
LIBPRI_VERSION=1.4.11.5
ADDONS_VERSION=1.6.2.3



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

[ ! -d "$INSTALL_DIR" ] && echo "Installation dir $INSTALL_DIR not found." && exit -1
[ ! -d "$COMPILE_DIR" ] && echo "Compilation dir $COMPILE_DIR not found." && exit -2

which aptitude && aptitude install -y build-essential linux-headers-`uname -r` libncurses5-dev libmysqlclient15-dev libxml2-dev

#####################################################################
# Create the main compilation directories

echo =========== Asterisk Framework ========
mkdir -p $COMPILE_DIR/asterisk-`date +%F_%H-%M-%S`
cd $COMPILE_DIR/asterisk-`date +%F_%H-%M-%S`
mkdir src

if yesno --timeout 10 --default yes "Download, compile, and install libpri: yes or no (default yes)? "; then
	LIBPRI=yes
fi

if yesno --timeout 10 --default yes "Download, compile, and install dahdi: yes or no (default yes)? "; then
	DAHDI=yes
fi

if yesno --timeout 10 --default yes "Download, compile, and install asterisk-addons: yes or no (default yes)? "; then
	ADDONS=yes
fi

#####################################################################
# libpri optional installation

if [ ! -z $LIBPRI ]; then
	echo ============= Now retrieving packages.... ======
	wget http://downloads.asterisk.org/pub/telephony/libpri/releases/libpri-$LIBPRI_VERSION.tar.gz
	mv libpri-$LIBPRI_VERSION.tar.gz src

	echo  ============= Uncompressing packages.... ======
	tar -vxzf src/libpri-$LIBPRI_VERSION.tar.gz

	echo  ============= Compiling packages.... ======
	cd libpri-$LIBPRI_VERSION
	make
	make install DESTDIR=$INSTALL_DIR || exit -1
	cd ..
fi

#####################################################################
# Dahdi optional installation


if [ ! -z $DAHDI ]; then
	echo ============= Now retrieving packages.... ======
	wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/releases/dahdi-linux-complete-$DAHDI_VERSION.tar.gz
	mv dahdi-linux-complete-$DAHDI_VERSION.tar.gz src

	echo  ============= Uncompressing packages.... ======
	tar -vxzf src/dahdi-linux-complete-$DAHDI_VERSION.tar.gz

	echo  ============= Compiling packages.... ======
	cd dahdi-linux-complete-$DAHDI_VERSION

	make || exit -1
	make install || exit -1
	make config || exit -1
	make samples || exit -1
	cd ..
fi

#####################################################################
# Asterisk installation

echo ============= Now retrieving packages.... ======
wget http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-$ASTERISK_VERSION.tar.gz
mv asterisk-$ASTERISK_VERSION.tar.gz src

echo  ============= Uncompressing packages.... ======
tar -vxzf src/asterisk-$ASTERISK_VERSION.tar.gz

echo  ============= Compiling packages.... ======
cd asterisk-$ASTERISK_VERSION
./configure --prefix=$INSTALL_DIR
make
make install
make config
make samples


#####################################################################
# Asterisk ADDONS optional installation

if [ ! -z $ADDONS ]; then
	echo ============= Now retrieving packages.... ======
	wget http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-addons-$ADDONS_VERSION.tar.gz
	mv asterisk-addons-$ADDONS_VERSION.tar.gz src

	echo  ============= Uncompressing packages.... ======
	tar -vxzf src/asterisk-addons-$ADDONS_VERSION.tar.gz

	echo  ============= Compiling packages.... ======
	cd asterisk-addons-$ADDONS_VERSION
	./configure --prefix=$INSTALL_DIR
	make || exit -1
	make install || exit -1
	make config || exit -1
	make samples || exit -1
	cd ..
fi


#####################################################################
# Configuracion de Codecs adicionales
#                          

echo =========== Addition Codec Installation ========
# Codec G729
echo "Configurando Codec G.729"
wget -O $INSTALL_DIR/lib/asterisk/modules http://asterisk.hosting.lv/bin/codec_g729-ast18-gcc4-glibc-pentium.so

# Codec G723
echo "Configurando Codec G.723"
wget http://asterisk.hosting.lv/bin/codec_g723-ast18-gcc4-glibc-pentium.so
 

#-----------------------------------------------------------------------
#
# Configuracion de voces en Espanyol
#                          
#----------------------------------------------------------------------
 
echo =========== Spanish Sounds Installation ========
# Descargamos los ficheros de voces en Espanyol
cd $COMPILE_DIR
echo "Descargando el conjunto de voces en espanyol de Alberto Sagredo"
echo "esta descarga varia en funcion de la conexion de Internet que"
echo "tenga el equipo, aproximadamente descargando >50MB"
wget http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-g729-1.4.tar.gz
wget http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-alaw-1.4.tar.gz
wget http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-ulaw-1.4.tar.gz
wget http://www.voipnovatos.es/voces/voipnovatos-extra-sounds-es-gsm-1.4.tar.gz
wget http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-g729-1.4.tar.gz
wget http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-alaw-1.4.tar.gz
wget http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-ulaw-1.4.tar.gz
wget http://www.voipnovatos.es/voces/voipnovatos-core-sounds-es-gsm-1.4.tar.gz
wget http://www.voipnovatos.es/voces/asterisk-voces-es-v1_2-moh-voipnovatos.tar.gz

# Descomprimismos las voces en Espanyol
echo "======== Installing files ================"
mkdir -p $INSTALL_DIR/var/lib/asterisk
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-extra-sounds-es-g729-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-extra-sounds-es-alaw-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-extra-sounds-es-ulaw-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-extra-sounds-es-gsm-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-core-sounds-es-g729-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-core-sounds-es-alaw-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-core-sounds-es-ulaw-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/voipnovatos-core-sounds-es-gsm-1.4.tar.gz
tar xvzf -C $INSTALL_DIR/var/lib/asterisk/sounds $COMPILE_DIR/asterisk-voces-es-v1_2-moh-voipnovatos.tar.gz

echo  ============= Compilation finished.  ======
