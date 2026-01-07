#!/usr/bin/env bash
# Upload media to Jellyfin
#   Uses dmenu for prompting
# Takes source-path as a parameter

shopt -s nullglob globstar extglob

EPISODE_PATTERN="[sS]([0-9]+)[eE]([0-9]+)"
VERBOSE=true
DRY_RUN=false
MEDIA_TYPE=
MEDIA_NAME=
ARGS=( )

usage() {
	cat <<-EOF
	Usage: ${0##*/} [options] SOURCE
	Options:
	 -d, --dry-run    Show what will happen without causing changes. Overrides -q/--quiet
	 -h, --help       Show this message.
	 -n, --name NAME  The name of the media that is being moved.
	 -t, --type TYPE  What type of media is being moved. One of: show, movie
	 -q, --quiet      Disable commandline output
	EOF
}

filter_video_files() {
	local path=$1

	echo "$path"/*.@(mkv|mp4|m4a)
}

copy-and-chown() {
	local src="$1"
	local dest="$2"
	local dest_dir="$(dirname "$2")"

    if $VERBOSE; then echo "'$src' -> '$dest'"; fi
	if $DRY_RUN; then return 0; fi
	
	mkdir -p "$dest_dir"
	cp "$src" "$dest"
	chown jellyfin:nas_apps "$dest"
}

track-show() {
	local name="$1"
	[[ -n "$(tv-tracker list "$name" -s)" ]] && return 0
	echo "Warning: '$name' was not yet tracked. Automatically adding..."
	# Todo: Find a way to do this interactively with dmenu - Pipes?
	tv-tracker track "'$name'" -q
}

process-show() {
	local src_path="$1"
	local name="$2"
	local dest_path="/mnt/jellyfin/Shows"

	# Make associative array of episode names indexed by season-number,episode-number
	# This should be a function (grumble grumble grumble)
	track-show "$name"

	declare -A episodes
	readarray -t <<< $(tv-tracker fetch-episodes "$name" --name-only -q)
	for episode_name in "${MAPFILE[@]}"; do
		[[ $episode_name =~ $EPISODE_PATTERN ]]
		local s="${BASH_REMATCH[1]}"
		local e="${BASH_REMATCH[2]}"
		episodes[$s,$e]="${episode_name}"
	done
	
	for file in $(filter_video_files $src_path); do
		if ! [[ $file =~ $EPISODE_PATTERN ]]; then
			echo "INFO: $file doesn't have a Season / Episode. Skipping..."; continue
		fi

		local s="${BASH_REMATCH[1]}"
		local e="${BASH_REMATCH[2]}"
		local ext="${file##*.}"
		local dest="$dest_path/$name/Season ${s##0}/${episodes[$s,$e]}.$ext"
		copy-and-chown "$file" "$dest"
	done
}

process-movie() {
	local src_path="$1"
	local name="$2"
	local dest_path="/mnt/jellyfin/Movies"
}

parse-args() {
	getopt -T
	if (( $? != 4 )); then
		echo >&2 "Incompatible version of 'getopt', falling back to dmenu..."; exit 1
	fi
	
	params="$(getopt -o t:n:qdh -l type:,name:,quiet,dry-run,--help --name "$0" -- "$@")"
	
	if (( $? != 0 )); then
		usage; exit 2
	fi
	
	eval set -- "$params"
	
	while (( $# > 0 )); do
		case "$1" in
			-t|--type)
				if [[ "${2,,}" =~ (movie|show) ]]; then
					MEDIA_TYPE="${2,,}"
				else
					echo >&2 "Invalid type '$2'. Must be either 'show' or 'movie'"; exit 2
				fi
				shift 2;;
			-n|--name)
				MEDIA_NAME="$2"
				shift 2;;
			-q|--quiet)
				if ! $DRY_RUN; then
					VERBOSE=false
				fi
				shift 1;;
			-d|--dry-run)
				DRY_RUN=true
				VERBOSE=true
				shift 1;;
			-h|--help)
				usage; exit 1;;
			--)
				shift; break;;
			esac
	done
	
	ARGS=( "$@" ) # Return any remaining args (should be positional args)
}

interactive-args() {
	if [[ -z "$MEDIA_TYPE" ]]; then
		TYPE=$(echo -e "Show\nMovie" | dmenu -l 2 -i -p "Select Media Type")
		MEDIA_TYPE="${TYPE,,}"
		[[ -n "$MEDIA_TYPE" ]] || exit 1 
	fi

	if [[ -z "$MEDIA_NAME" ]]; then
		MEDIA_NAME=$(echo "" | dmenu -p "$MEDIA_TYPE name: " <&-)
		[[ -n $MEDIA_NAME ]] || exit 1
	fi
	
	# Todo: Introduce --interactive flag
	if [[ "$INTERACTIVE" ]]; then
		local mode=$(echo -e "Default\nDry-Run\nQuiet" | dmenu -l 3 -i -p "Select mode")
		[[ -n $mode ]] || exit 1
	-d, --dry-run		Show what will happen without causing changes. Overrides -q/--q
		case "$mode" in
			Default)
				DRY_RUN=false;
				VERBOSE=true;;
			Quiet) 
				DRY_RUN=false;
				VERBOSE=false;;
			Dry-Run)
				DRY_RUN=true;
				VERBOSE=true;;
		esac
	fi
}

main() {
	local src_path=${1%%+(/)} # Trim trailing /
	
	if [[ -z "$src_path" ]]; then
		echo >&2 "Invalid source path. (Was either empty or /)"; exit 2
	fi
	if $VERBOSE; then
		echo "Uploading $MEDIA_TYPE '$MEDIA_NAME' from '$src_path'"
		echo "dry-run=$DRY_RUN"
		echo
	fi

	if ! $DRY_RUN; then mount-nfs.sh; fi
	
	case "$MEDIA_TYPE" in
		show)  process-show "$src_path" "$MEDIA_NAME";;
		movie) process-movie "$src_path" "$MEDIA_NAME";;
	esac
}

if [[ -z "${1%%+(/)}" ]]; then
	echo "Missing source path" >&2; exit 1
fi



parse-args "$@" || exit $?
if (( ${#ARGS[@]} != 1 )); then
	echo >&2 "Expected 1 positional arg got ${#ARGS[@]}. Args were: ${ARGS[@]}"
	echo
	usage; exit 2
fi
interactive-args || exit $?
main "$ARGS"
