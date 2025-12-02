#!/usr/bin/env bash

NFS_IP="10.0.0.99"

is-nfs(){
	[[ "$(stat --file-system --format=%T "$1")" == "nfs" ]]
}

mount-if-needed() {
	local remote="$1"
	local local="$2"

	is-nfs "$local" && echo 0 && return 0
	sudo mount -t nfs "$remote" "$local"
	echo $?
}

if $(is-nfs /mnt/jellyfin) && $(is-nfs /mnt/vanasa); then
	exit 0
fi

JELLYFIN=$(mount-if-needed "$NFS_IP:/mnt/vdev1/Media" "/mnt/jellyfin")
VANASA=$(mount-if-needed "$NFS_IP:/mnt/vdev1/Shared" "/mnt/vanasa")

if (( VANASA != 0 )) || (( JELLYFIN != 0 )); then
	notify-send "🔴 Failed to mount NFS shares"
else
	notify-send "🟢 Mounted NFS shares"
fi
