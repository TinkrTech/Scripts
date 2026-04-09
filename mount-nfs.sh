#!/usr/bin/env bash

# Load env for nas
. /home/jade/Scripts/envs/nas-paths.sh || exit 2

is-nfs(){
	[[ "$(stat --file-system --format=%T "$1")" == "nfs" ]]
}

HAS_FAILED=false
NO_CHANGE=true
for key in "${!NAS_MOUNT_PATHS[@]}"; do	
	is-nfs "${NAS_MOUNT_PATHS[$key]}" && continue || NO_CHANGE=false
	sudo mount -t nfs "${NAS_REMOTE_PATHS[$key]}" "${NAS_MOUNT_PATHS[$key]}" || HAS_FAILED=true
done

if $NO_CHANGE; then
	exit 0
elif $HAS_FAILED; then
	notify-send "🔴 Failed to mount NFS shares"
else
	notify-send "🟢 Mounted NFS shares"
fi
