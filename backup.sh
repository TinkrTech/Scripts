#!/usr/bin/env bash
# A script to incrementally backup to local and remote destinations

shopt -s globstar extglob nullglob 

DRY_RUN=false
printf -v TIMESTAMP "%(%F-%H%M)T" -1 # yyyy-mm-dd-HHMM
LOG_DIR="/etc/logs/backup-sh/$timestamp.log"

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
)

local_base_dest="/mnt/data/Backup"
remote_base_dest="/mnt/vanasa/Jade/0 - Backup"


usage() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "-d, --dry-run	Show what the results of the operation would be"
	echo "-h, --help	Show this message"
	echo "See Also:"
	echo "restore.sh"
}

get-args() {
	getopt -T
	if (( $? != 4 )); then 
		echo >&2 "Incompatible version of 'getopt', exiting..."; exit 2
	fi
	
	params="$(getopt -o dh -l dry-run,help --name="$0" -- "$@")"

	(( "$?" == 0 )) || (usage; exit 2)
	
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

main() {	
	local dry_run=
	if $DRY_RUN; then
		local dry_run="--dry-run"
	fi

	local local_dest="$local_base_dest/$TIMESTAMP"

	local previous=$(ls "$local_base_dest" -1 | tail -1)
	local link_dest=
	if [[ -n "${previous}" ]]; then
		local link_dest="--link-dest='$previous'"
	fi

	local path
	for path in "${sources[@]}"; do
		# archive, verbose, human-readable, relative, compress
		rsync -avhRz $dry_run  \
			--delete \
			$link_dest \
			--exclude-from=<(printf '%s\n' "${exclude_patterns[@]}") \
			"${path%%+(/)}" \
			"$local_dest"
	done
	
	# rsync $flags -avh "${local_dest%%+(/)}" "$remote_dest"
}

get-args "$@"
echo $TIMESTAMP
main
