#!/usr/bin/env bash

TIME_FORMAT="%(%F-%H%M)T" # yyyy-mm-dd-HHMM 
TIME_RE='[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}'

LOCALS=( 
	"/mnt/data/Backup"
)

REMOTES=(
	"vanasa@10.0.0.99:/mnt/vdev1/Shared/Jade/Backup"
)

list-backups() {
	# Populates VARIABLE with all of the SERIES backups in LOCATION
	# Sorted in reverse order 
	# usage: list-backups VARIABLE LOCATION [SERIES]
	local -n backups_="$1"
	local location="${2%%/}"	
	local series
	if (( $# >= 3 )); then
		series=$3
	fi
	series="${series:+$series.}"
	readarray -t backups_ <<< $(rsync "$location/" | awk '{print $5}' | egrep "${series}$TIME_RE" | sort -r)
}

