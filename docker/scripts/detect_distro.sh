#! /usr/bin/env sh

# Exit in case of error
set -e

DISTRO=$(cat /etc/*-release | sed -n 's/PRETTY_NAME=//p')

if [[ "$DISTRO" =~ "Ubuntu" ]]; then
  echo "detected distro: $DISTRO"
  task -l
else
  echo "detected distro: $DISTRO"
  go-task -l
fi
