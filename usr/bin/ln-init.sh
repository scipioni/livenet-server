
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



install(){
    echo "Installazione dei requisiti di sistema"
    #TODO check if debian, centos, etc
    apt install -y  bash debootstrap schroot syslinux gdisk git wget curl nfs-kernel-server tftpd-hpa xorriso pigz pxelinux zfsutils-linux
    
    echo "ottenere i sorgenti e selezionare il branch"
    git clone https://github.com/scipioni/livenet-server.git
    git checkout bionic
    
    
    path="$(pwd)"
    echo ${path}
    cd ${path}/livenet-server
    rsync -avb etc/ /etc/
    rsync -avb usr/ /usr/
    
    echo "salvare il path di installazione"
	cat >> /etc/default/livenet <<QQSCHROOT
INSTALLPATH=${path}/livenet-server

QQSCHROOT
}

upgrade(){
    . ./etc/default/livenet
    cd ${INSTALLPATH}/
    git pull --rebase --stat origin bionic
    rsync -avb etc/ /etc/
    rsync -avb usr/ /usr/
    
    echo "salvare il path di installazione"
	cat >> /etc/default/livenet <<QQSCHROOT
INSTALLPATH="$(pwd)/livenet-server"

QQSCHROOT
}

dhcpinstall(){
	apt install -y isc-dhcp-server 
	echo "configura l'interfaccia su cui si espone il dchp"
	
}
#Inizializza da dispositivo vergine
#
initblk()
{
    
    . /etc/default/livenet
    
    echo "Indica il percorso completo di un dispositivo a blocchi da dedicare per Livenet"
    read -p "Percorso assoluto: " blkzfs
    echo $blkzfs
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
            sgdisk -a1 -n2:34:2047  -t2:EF02 ${blkzfs}
            echo "Creazione del pool ${blkzfs}..."
            zpool create LNPZFS ${blkzfs}
            
            echo "creazione dei volumi  di default"
            
            echo zfs create ${LNPZFS}/${LNVZFS}
            zfs create ${LNPZFS}/${LNVZFS}
            echo zfs create ${LNPZFS}/${LNVZFS}/images
            zfs create ${LNPZFS}/${LNVZFS}/images
            echo zfs create ${LNPZFS}/${LNVZFS}/boot
            zfs create ${LNPZFS}/${LNVZFS}/boot
            
            #installo i file per il boot di livenet via pxe
            echo "Costruisco l'immagine di avvio di sistema via pxe"
            
            mkdir ${BOOT}/pxelinux.cfg
            cp -a /usr/lib/syslinux/* /livenet/boot
            cp /usr/lib/PXELINUX/pxelinux.0 ${BOOT}
            mv ${BOOT}/modules/efi64/* ${BOOT}
            
            #creo file default
            echo "Configurazione di TFTP"
            cp ${path}/livenet-server/usr/share/doc/livenet-server/examples ${BOOT}/pxelinux.cfg/default
            
			cat > /etc/default/tftp-hpa <<QWK
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="${BOOT}"
TFTP_ADDRESS="0.0.0.0:69"
FTP_OPTIONS="--secure"
QWK
            
            #configurazione di DHCP
            
            
            read -e -p "Vuoi installare il server DHCP: " -i "N" YN
            YN=${YN:-N}
            if [ $YN == "y" ] || [ $YN == "Y" ]; then
                echo "installa dhcp"
				dhcpinstall
            else
                echo "ok non faccio nulla"
            fi
            
        fi
        
    else
        echo "Il dispositivo indicato non esiste"
        
    fi
    
}

usage()
{
		 cat << EOF
        Usage: ln-init <options>

        Options:
        --h: show this messages
		--install
        --show: show curret livenet configuration
        --initblk: initialize device block for livenet storage
        --version,-v

EOF
}

while true; do
    case $1 in
        -h|--help)
            usage
            exit 0
        ;;
        -i|--install)
            install
            exit 0
        ;;
        -u|--upgrade)
            upgrade
            exit 0
        ;;
        -v|--version)
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
