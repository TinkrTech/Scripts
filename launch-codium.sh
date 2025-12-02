#!/usr/bin/env bash

/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=com.vscodium.codium --file-forwarding com.vscodium.codium $1
