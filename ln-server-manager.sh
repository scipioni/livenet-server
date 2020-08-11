#!/bin/bash

# Initialize livenet environment
# Build livenet pool
# create volume
# install dhcp-server
# configre trivial ftp

#Initialize zpool for livenet

#echo "Check livenet parameteres in /etc/defaul/livenet"

#vi /etc/default/livenet (

printf '%s\n' '    __  _                           _   '
printf '%s\n' '  / / (_)__   __ ___  _ __    ___ | |_ '
printf '%s\n' ' / /  | |\ \ / // _ \| `_ \  / _ \| __|'
printf '%s\n' '/ /___| | \ V /|  __/| | | ||  __/| |_ '
printf '%s\n' '\____/|_|  \_/  \___||_| |_| \___| \__|'
printf '%s\n' ''

echo "Utilità di installazione del sistema"
declare CONFIG_FILE=etc/default/livenet
if [ ! -f $SOURCE ]; then
    echo "File di configurazione di livenet non presente, installare e configurare prima di proseguire il setup"
fi


function do_parse() {
    SECTION=$1
    unset ARGUMENTS

    for section in $(sed -n "/"${SECTION}"/,/^$/{/./p}" ${CONFIG_FILE} | tail -n +2); do
        declare $(echo ${section} | cut -d "=" -f1)
        eval ${section}
        export $section
        ARGUMENTS+=($section)
    done    
}

function do_create_zfs(){
    set +x
    disk=$1
    do_parse zpool
    local ZPOOL
    for a in "${ARGUMENTS[@]}"; do
        ZPOOL=$(echo $a | cut -d "=" -f2)
        echo "Creazione del pool ${ZPOOL}..."
        zpool create ${ZPOOL} ${disk}
        zfs set mountpoint=none ${ZPOOL}
    done
    do_parse dataset
    for a in "${ARGUMENTS[@]}"; do
        ZFS_PATH=$(echo $a | cut -d "=" -f2)
        echo "zfs create ${ZFS_PATH}"
        zfs create ${ZFS_PATH}
        zfs set mountpoint=none ${ZFS_PATH}
    done
    
set +x
}

do_create_mountpoint(){
    echo "creazione dei mountpoint..."
    do_parse mountpoint
    for a in "${ARGUMENTS[@]}"; do
        eval $a
        mkdir -p $(echo $a | cut -d "=" -f2)
    done
}
#do_parse dataset
#do_parse mountpoint


install() {
    echo "Installazione dei requisiti di sistema"
    #TODO check if debian, centos, etc
    apt install -y bash debootstrap schroot syslinux gdisk git wget curl nfs-kernel-server tftpd-hpa xorriso pigz pxelinux zfsutils-linux

    echo "ottenere i sorgenti e selezionare il branch"
    cd ~
    git clone https://github.com/scipioni/livenet-server.git
    cd ./livenet-server
    git checkout bionic

    path="$(pwd)"
    echo ${path}
    cd ${path}/
    rsync -avb etc/ /etc/
    rsync -avb usr/ /usr/
    chmod +x /usr/bin/ln-image
    chmod +x /usr/bin/ln-image-srv
    echo "salvare il path di installazione"

    cat >>/etc/default/livenet <<QQSCHROOT
INSTALLPATH=${path}/
QQSCHROOT
}

upgrade() {
    cd ${INSTALLPATH}/
    git pull origin bionic
    rsync -avb etc/ /etc/
    rsync -avb usr/ /usr/
    chmod +x /usr/bin/ln-image
    chmod +x /usr/bin/ln-image-srv


}

dhcpinstall() {

    apt install -y isc-dhcp-server
    IPGW=$(/sbin/ip route | awk '/default/ { print $3 }')
    NICDEFAULT=$(/sbin/ip route | awk '/default/ { print $5 }')
    echo "Interfaccia di rete in uso:  ${NICDEFAULT}"
    echo "Interfacce di rete usabili: "
    echo $(ls /sys/class/net | grep en* | sort | sed -e "s/\<${NICDEFAULT}\>//g")

    echo "Configura l'interfaccia su cui si espone il dchp"
    read -p "Indica l'interfaccia da usare per il server DHCP: " NIC
    sed -i "/INTERFACESv4/c\INTERFACESv4="${NIC}"" /etc/default/isc-dhcp-server
    cp -r ${INSTALLPATH}/usr/share/doc/livenet-server/examples/dhcpd.conf /etc/dhcp/dhcpd.conf
    read -p "Premi un tasto per configurare dhcpd.conf"
    cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.back
    nano /etc/dhcp/dhcpd.conf
    echo "configurazione delle interfacce di rete"
    cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.back
    echo "Modifica il gateway e l'ip statico dell'interfaccia"

    read -p "Premi un tasto per configurare netcfg.conf, al termine esegui netplan apply"
    nano /etc/netplan/01-netcfg.yaml

    netplan apply
    service isc-dhcp-server restart
    service tftpd-hpa restart

}
#Inizializza da dispositivo vergine
#
initblk() {

    echo "Ricerca dei dischi in corso"
    blkzfs=""
    DISK_BY_ROOT=$(lvs -o devices $(df /usr | grep '^/' | cut -d' ' -f1) --noheadings)
    IGNORE=$(readlink -f /dev/disk/by-path/$(ls -lohgG /dev/disk/by-path | grep $(echo $DISK_BY_ROOT | cut -d "(" -f 1 | cut -d "/" -f3) | cut -d " " -f8 | awk -F '-part' '{print $1}'))
    PS3="Enter a number: "
    #touch "$QUIT"
    disks=($(lsblk -npd --output NAME -I 8 | grep -v ${IGNORE}))
    while true; do
        echo "Digit q to exit"
        select ITEM in ${disks[*]}; do
            case $ITEM in
            *)
                echo "Select disk: $ITEM"
                break
                ;;

            esac
        done
        if [ "$REPLY" = "q" ]; then
            break
        fi
        if [ ! -z $ITEM ]; then
            blkzfs=${ITEM}
            break;
        else
            echo "Selection not valid"
            continue
        fi
    done

    #controllo se il dispositivo esiste
    if [ -b "$blkzfs" ]; then
        #se esiste, controllo se esiste il punto di mount
        if [ -d "/livenet" ]; then
            # Control will enter here if /livenet exists.
            echo "Il  punto di mount predefinito esiste, rimuovere /livenet prima di proseguire"
        else

            # Control will enter here if /livenet not exists.
            echo "Pulizia del dispositivo"
            echo "Rimozione del pool ${LNPZFS} se esistente..."
            zpool destroy ${LNPZFS}
            echo "Pulizia del disco..."
            sgdisk --clear -g ${blkzfs}
            echo "Creazione partizione primaria"
            sgdisk -a1 -n2:34:2047 -t2:EF02 ${blkzfs}

            do_create_zfs ${blkzfs}
            do_create_mountpoint 


            #creo un utente per inviare i volumi
            #useradd -s /bin/bash --create-home lnsrvsend
            #chroot ${R} /bin/bash -c "passwd -d lnsrvsend"
            #chroot ${R} /bin/bash -c "usermod -p $(openssl passwd -1 "lnsrv") lnsrvsend"

            #installo i file per il boot di livenet via pxe
            echo "Costruisco l'immagine di avvio di sistema via pxe a 64 bit"

            mkdir ${BOOT}/pxelinux.cfg
            cp -a /usr/lib/syslinux/modules/efi64/* ${BOOT}
            cp /usr/lib/PXELINUX/pxelinux.0 ${BOOT}
            #mv ${BOOT}/modules/efi64/* ${BOOT}

            #creo file default
            echo "Configurazione di TFTP"
            cp ${INSTALLPATH}/usr/share/doc/livenet-server/examples/default.cfg ${BOOT}/pxelinux.cfg/default

            cat >/etc/default/tftpd-hpa <<QWK

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="${BOOT}"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
QWK

        fi

    else
        echo "Il dispositivo indicato non esiste"

    fi

}

usage() {
    cat <<EOF
Usage: ln-init <options>

Options:
--h: show this messages
--install: install livenet package
--installdchp: install and configure dhcp server
--upgrade: upgrade livenet package
--show: show curret livenet configuration
--initblk: initialize device block for livenet storage
--version,-v

EOF
}

while true; do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    -i | --install)
        install
        exit 0
        ;;
    --installdhcp)
        dhcpinstall
        exit 0
        ;;
    -u | --upgrade)
        upgrade
        exit 0
        ;;
    -v | --version)
        #apt-cache show livenet-server | sed -n 's/^Version:.\([0-9\.]\+\)-.*/\1/p'
        exit 0
        ;;
    --initblk)
        initblk
        exit 0
        ;;
    --show)
        #show current configuration livenet
        #path of storage
        #network configuration
        cat /etc/default/livenet
        exit 0
        ;;
    *)
        #shift
        if [ -n "$1" ]; then
            echo "Error: bad argument"
            exit 1
        fi
        break
        ;;
    esac
    shift
done

usage
