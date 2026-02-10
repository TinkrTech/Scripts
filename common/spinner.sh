#!/usr/bin/env bash
# Author: Jade T
# Date: Jan 05, 2026
# License: MIT
#
# Modified from https://github.com/bahamas10/ysap/blob/main/code/2026-01-07-spinner/spinner
# Spinners can be downloaded from:
# 	https://raw.githubusercontent.com/sindresorhus/cli-spinners/refs/heads/main/spinners.json
# 
# Note: spinners.json must be in the SAME DIRECTORY as this script

SPINNERS_FILE="$(dirname $0)/spinners.json"
SPINNER_PID=
FRAMES=( '/' '-' '\' '|' )
INTERVAL=200
declare ARGS

usage() {
	cat <<-EOF
	Usage: ${0##*/} [options] -- PROGRAM
	Show an animated spinner until PROGRAM terminates
	Options:
	 -h, --help           Print this message
	     --list-themes    Print a list of themes acccessible themes
	                      (Pipe to 'column' for better legibility)
	 -t, --theme=<THEME>  Select a spinner theme from themes.json 
	EOF
}

spin() {
	local frame
	printf -v DELTA "%d.%03d" $((INTERVAL / 1000)) $((INTERVAL % 1000))
	while true; do
		for frame in "${FRAMES[@]}"; do
			printf "%s\r" "$frame"
			sleep "$DELTA"
		done
	done
}

parse-args() {
	getopt -T
	if (( $? != 4 )); then
		echo >&2 "Incompatible get-opt version..."; exit 2
	fi

	local params="$(getopt -o ht: -l help,list-themes,theme: --name "${0##*/}" -- "$@")"
	
	if (( $? != 0 )); then
		usage >&2; exit 2
	fi
	
	eval set -- "$params"
	
	while (( $# > 0 )); do
		case "$1" in
			-h|--help)  usage; exit 1;;
			-t|--theme) 
				mapfile -t FRAMES < <(jq -r ".$2.frames[]" "$SPINNERS_FILE")
				INTERVAL="$(jq -r ".$2.interval" "$SPINNERS_FILE")"
				shift 2;;
			--list-themes)
				echo "$(jq -r 'keys[]' "$SPINNERS_FILE" | sort -V)"; exit 1;;
			--)
				shift; break;;
		esac
	done

	ARGS=( "$@" ) # Return remaining args
}

cleanup() {
	if [[ -n $SPINNER_PID ]]; then
		kill "$SPINNER_PID"
		printf '\e[?25h' # Restore cursor
	fi
}

main() {
	if (( $# == 0 )); then
		usage >&2; exit 1
	fi
	
	trap cleanup EXIT
	printf '\e[?25l' # Hide cursor	
	spin &
	SPINNER_PID=$!
	
	"$@"
}

# Exit with code 0 from information commands (help, list-themes)
parse-args "$@" || exit $(( $? - 1 ))
main "${ARGS[@]}"
