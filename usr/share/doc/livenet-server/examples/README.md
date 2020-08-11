# DHCP server
apt install isc-dhcp-server

apt install syslinux pxelinux

cp /usr/lib/PXELINUX/* /livenet/boot/


# share 
zfs set sharenfs="ro" rpool/livenet/images/bionic

# test
mount.nfs4 -o ro localhost:/livenet/images/bionic /tmp/test/
