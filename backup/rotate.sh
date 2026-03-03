#!/usr/bin/env bash
# Rotates daily backups older than 1 week
# Rotates weekly backups older than 1 month
# Rotates monthly backups older than 6 months

shopt -s globstar extglob nullglob

cd "${0%/*}" # Normalize working directory
source constants.sh

rotate() {
	local location="${1%%/}"
	
	if [[ -z "$location" ]]; then
		echo "Invalid location. Aborting..."; exit 2;
	fi

	local series="$2"
	local keep_count=
	case "$series" in
		daily) keep_count=7;;
		weekly) keep_count=4;;
		monthly) keep_count=6;;
		*) echo >&2 "Unrecognized backup type '$backup_type'. Aborting..."; exit 1;;
	esac
	
	# The list of matching backups in reverse chronological order	
	local matching 
	list-backups matching "$location" "$series"

	local delete_count=$(( "${#matching[@]}" - keep_count))
	if (( $delete_count < 0 )); then
		echo "  $series - [Nothing to delete]"
		return
	fi

	local to_delete=( "${matching[@]:$keep_count:$delete_count}" )
	
	# Do the deletions here
	local item
	for item in ${to_delete[@]}; do
		item="$location/${item%%/}"
		if [[ -z "${item%%/}" ]]; then
			echo "WARNING: item to be deleted was empty. Skipping"
			continue
		fi
		echo "  $series - Removing $item"
		rm -rf "$item"
	done
}

for location in "${LOCALS[@]}" "${REMOTES[@]}"; do
	echo "Rotating scheduled backups in '$location'"
	for series in "daily" "weekly" "monthly"; do
		rotate "$location" "$series"
	done
done
