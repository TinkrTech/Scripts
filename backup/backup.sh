#!/usr/bin/env bash
# A script to incrementally backup to local and remote destinations

usage() {
	cat <<-EOF
	Usage: ${0##*/} [options]
	Options:
	 -d, --dry-run        Show what the results of the operation would be
	 -h, --help           Show this message
	 -s, --series SERIES  Use previous backups with this series as the reference point. 
	                      Backups look like SERIES.TIMESTAMP
	See Also:
	 restore.sh, rotate.sh
	EOF
}

shopt -s globstar extglob nullglob 

cd "${0%/*}" || exit 2 # Normalize working directory
source constants.sh
LOG_FILE="/var/log/backup-sh/$TIMESTAMP.log"

DRY_RUN=false
SERIES=

sources=(
	/home/jade/{.config,Scripts}
	/mnt/data/{Code,Documents,Notes,Pictures,Videos}
)

exclude_patterns=(
	"Code/**/.venv"
	"Code/**/node_modules"
	"Code/**/.ipynb_checkpoints"
	"Code/thrive-assessment/Infrastructure/terraform/.terraform"
	"Code/**/.mypy_cache"
	"Code/**/__pycache__"
	"Code/**/.pnpm"
	"Code/**/target"
	"**/*cache"
	".config/**/*.log"
	".config/**/*.log.*"
	".config/libreoffice"
	".config/session"
	".config/chromium"
	".config/transmission/torrents"
	".config/transmission/resume"
	".config/Proton Mail"
)

get-args() {
	getopt -T
	if (( $? != 4 )); then
		echo >&2 "Incompatible version of 'getopt', exiting..."; exit 2 
	fi
	
	if ! params="$(getopt -o dhs: -l dry-run,help,series: --name="$0" -- "$@")"; then
		usage; exit 2
	fi
	
	eval set -- "$params"

	while (( $# > 0 )); do
		case "$1" in
			-d|--dry-run) DRY_RUN=true; shift;;
			-h|--help) usage; exit 1;;
			-s|--series) SERIES="${2,,}"; shift 2;; 
			--) shift;;
		esac
	done
}

get-link-dest() {
	# Usage: get-link-dest output-variable <folder-with-backups> [<series>]
	# Find the most recent backup in a series
	# If the series doesn't exist, leave the variable unset
	# If it exists then set <link_dest_arg> to "--link-dest=<path-to-file>"
	# Otherwise leave <link_dest_arg> unset
	local -n link_dest_arg="$1"
	local dest_parent="$2"
	local series_backups
	
	list-backups series_backups "$dest_parent" "$SERIES" || exit 1
		
	if (( "${#series_backups[@]}" != 0 )); then
		local hostless_dest="${dest_parent#*:}"
		local link_dest_arg="--link-dest='$hostless_dest/${series_backups[0]}'" 
		echo "$link_dest_arg"
	else
		echo "--link-dest=<unset>"
	fi
}

sync-to-dest() {
	echo "Backing up to '$1'${SERIES:+ with series '$SERIES'}"
	
	local dest_parent="$1"; shift
	local dest="$dest_parent/${SERIES:+$SERIES.}$TIMESTAMP"
	
	local passthru_args=( "$@" )
	local link_dest
	get-link-dest link_dest "$dest_parent"
	
	local dry_run=
	if $DRY_RUN; then 
		dry_run="--dry-run"
	fi
	
	local path
	for path in "${sources[@]}"; do
		# human-readable, archive, compress, relative
		rsync -hazRv $dry_run  \
			--delete \
			${passthru_args[@]} \
			$link_dest \
			--exclude-from=<(printf '%s\n' "${exclude_patterns[@]}") \
			"$path" \
			"$dest"
	done
	echo
}

main() {
	# Note: Since these happen at different points in time they may not be mutually in sync.
	
	local location
	for location in "${LOCALS[@]}"; do
		sync-to-dest "$location"
	done
	
	echo

	for location in "${REMOTES[@]}"; do	
		sync-to-dest "$location" --no-perms
	done
}

get-args "$@" || exit $(( $? - 1 ))

if ! $DRY_RUN; then
	main 2>&1 | tee "$LOG_FILE"
else
	main
fi
