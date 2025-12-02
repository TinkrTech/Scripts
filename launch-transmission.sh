#!/usr/bin/env bash
# Launch Transmission (Torrent client) after ensuring PIA is connected
set -eo pipefail

REGION="ca-montreal"

if [ $(piactl get connectionstate) != "Connected" ]; then
	notify-send "🟡 Connecting to PIA - $REGION" -a "Launch Transmission"
	piactl set region "$REGION"
	piactl connect
	until [ $(piactl get connectionstate) = "Connected" ]; do
	    sleep 0.25
	done
fi

if [ $(piactl get connectionstate) != "Connected" ]; then
	notify-send "🔴 Could not connect to PIA" -u critical -a "Launch Transmission"; exit 2
fi

notify-send "🟢 Connected to PIA - $(piactl get region)" -a "Launch Transmission"

transmission-gtk </dev/null &>/dev/null &
