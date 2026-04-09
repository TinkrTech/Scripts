#!/usr/bin/env bash
# Usage: launch-with-pia.sh PROGRAM
# Launch program after ensuring PIA is connected

set -eo pipefail

REGION="ca-montreal"

if [ $(piactl get connectionstate) != "Connected" ]; then
	notify-send "🟡 Connecting to PIA - $REGION" -a "Launch $1"
	piactl set region "$REGION"
	piactl connect
	until [ $(piactl get connectionstate) = "Connected" ]; do
	    sleep 0.25
	done
fi

if [ $(piactl get connectionstate) != "Connected" ]; then
	notify-send "🔴 Could not connect to PIA" -u critical -a "Launch $1"; exit 2
fi

notify-send "🟢 Connected to PIA - $(piactl get region)" -a "Launch $1"

"$1" </dev/null &>/dev/null &
