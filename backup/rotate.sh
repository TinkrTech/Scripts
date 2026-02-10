#!/usr/bin/env bash
# Rotates daily backups older than 1 week
# Rotates weekly backups older than 1 month
# Rotates monthly backups older than 6 months

shopt -s globstar extglob nullglob

cd "${0%/*}" # Normalize working directory
source constants.sh

rotate() {
	local backup_type=$1
	local location=${2%%/}
	local prefix="${PREFIXES[$backup_type]}"
	local keep_count=
	case "$backup_type" in
		daily) keep_count=7;;
		weekly) keep_count=4;;
		monthly) keep_count=6;;
		*) echo >&2 "Unrecognized backup type '$backup_type'. Aborting..."; exit 1;;
	esac
	
	local matching=( "$location/$prefix"* )
	local delete_count=$(( "${#matching[@]}" - keep_count))
	local to_delete=( "${matching[@]:0:$delete_count}" )
	# Do the deletions here
	for item in ${to_delete[@]}; do
		echo "Will remove $item"
	# 	rm -rf "$item"
	done
}

# rotate "daily" ~/Scripts/backup/test/

for location in "${LOCALS[@]}" "${REMOTES[@]}"; do
	for t in "daily" "weekly" "monthly"; do
		rotate "$t" "$location"
	done
done
