#!/bin/bash

# sudo apt install uml-utilities

sudo qemu-system-x86_64 -boot n -net tap -net nic
