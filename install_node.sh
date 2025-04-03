#!/bin/bash

# Exit if any commands fail
set -e

# Ensure that a version was passed
if [ -z "$1" ]; then
    echo "No Node.js version supplied for n."
else
    NODE_VERSION=$1
    sudo n install $NODE_VERSION
fi

exit 0



