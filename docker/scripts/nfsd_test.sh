#!/bin/sh
IS_MODULE=`lsmod | grep -o nfsd`
if [[ -z "${IS_MODULE}" ]]; then
    echo "${0}: Missing module nfsd: probing now..."
    sudo modprobe nfsd
fi
