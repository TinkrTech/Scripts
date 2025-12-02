#!/usr/bin/env bash
# Upload media to Jellyfin
#   Uses dmenu for prompting
# Takes source-path as a parameter

shopt -s nullglob
shopt -s globstar
shopt -s extglob

EPISODE_PATTERN="[sS]([0-9]+)[eE]([0-9]+)"
VERBOSE=
DRY_RUN=

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

spin-until-done() {
	local spinner=( '|' '/' '-' '\\' )
	local i=0
	
	while [[ -n $(ps --ppid $$ -o cmd | rg -v "ps|rg") ]]; do
		echo -ne "\rUploading Files...${spinner[i]}"
		i=$(( (i+1) % "${#spinner[@]}" ))
		sleep 0.15
	done
	echo "Done"	
}

main() {
	local src_path=${1%%+(/)} # Trim trailing /
	
	echo "src_path=$src_path"
	local media_type=$(echo -e "Show\nMovie" | dmenu -l 2 -i -p "Select Media Type")
	[[ -n $media_type ]] || exit 1 
	
	local media_name=$(echo "" | dmenu -p "$media_type name: " <&-)
	[[ -n $media_name ]] || exit 1

	local mode=$(echo -e "Default\nDry-Run\nVerbose" | dmenu -l 3 -i -p "Select mode")
	[[ -n $mode ]] || exit 1
	
	case "$mode" in
		Default) 
			DRY_RUN=false;
			VERBOSE=false;;
		Dry-Run)
			DRY_RUN=true;
			VERBOSE=true;;
		Verbose)
			DRY_RUN=false;
			VERBOSE=true;;
	esac
	
	if ! $DRY_RUN; then mount-nfs.sh; fi

	case "$media_type" in
		Show)  process-show "$src_path" "$media_name";;
		Movie) process-movie "$src_path" "$media_name";;
	esac

}

if [[ -z "${1%%+(/)}" ]]; then
	echo "Missing source path - Usage: $0 <path>" >&2; exit 1
fi

main $@
