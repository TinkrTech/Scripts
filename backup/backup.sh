#!/usr/bin/env bash
# A script to incrementally backup to local and remote destinations

usage() {
	cat <<-EOF
	Usage: ${0##*/} [options]
	Options:
	 -d, --dry-run  Show what the results of the operation would be
	 -h, --help     Show this message
	See Also:
	 restore.sh
	EOF
}

shopt -s globstar extglob nullglob 

DRY_RUN=false
printf -v TIMESTAMP "%(%F-%H%M)T" -1 # yyyy-mm-dd-HHMM
LOG_FILE="/var/log/backup-sh/$TIMESTAMP.log"

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
)

local_dest="/mnt/data/Backup"
remote_dest="vanasa@10.0.0.99:/mnt/vdev1/Shared/Jade/Backup"

get-args() {
	getopt -T
	(( $? == 4 )) || (echo >&2 "Incompatible version of 'getopt', exiting..."; exit 2)
	
	params="$(getopt -o dh -l dry-run,help --name="$0" -- "$@")"
	(( $? == 0 )) || (usage; exit 2)
	
	eval set -- "$params"

	while (( $# > 0 )); do
		case "$1" in
			-d|--dry-run)
				DRY_RUN=true; shift;;
			-h|--help)
				usage; exit 0;;
			--)
				shift;;
		esac
	done
}

sync-to-dest() {
	local dest_parent="$1"; shift
	local dest="$dest_parent/$TIMESTAMP" 
	
	local passthru_args=( "$@" )	

	local latest_backup=$(rsync "$dest_parent/" | tail -1 | awk '{print $5}')
	local link_dest=
	if [[ "$latest_backup" != '.' ]]; then
		local dest_hostless="${dest_parent#*:}"
		link_dest="--link-dest=$dest_hostless/$latest_backup"
	fi

	local dry_run=
	if $DRY_RUN; then 
		dry_run="--dry-run"
	fi
	
	echo "$link_dest ${passthru_args[@]}"
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
}

main() {
	sync-to-dest "$local_dest"
	
	# Note: Since these happen at different points in time they may not be mutually in sync.
	sync-to-dest "$remote_dest" --no-perms
}

get-args "$@"

if ! $DRY_RUN; then
	main 2>&1 | tee "$LOG_FILE"
else
	main
fi
