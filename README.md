# Livenet Server

Livenet can distribute and synchronize an ubuntu image to many PC. Used in university of Verona to manage hundreds of PC with Linux and VM guests.

https://projects.csgalileo.org/projects/livenet/wiki/Quick

# Default requirements

- one dedicaded hdd
- two NIC

# Install guide

git clone https://github.com/scipioni/livenet-server.git

git checkout origin bionic

Launch :
usr/bin/ln-init.sh --initblk
usr/bin/ln-init.sh --install
usr/bin/ln-init.sh --installdhcp


