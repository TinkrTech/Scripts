#!/usr/bin/env bash
# Periodically checks PIA port forward and transmission's 
# peer-port and updates the port if needed

SETTINGS_PATH=~/.config/transmission/settings.json
expected=$(jq '."peer-port"' .config/transmission/settings.json)
actual=$(piactl get portforward)

if [[ $actual == $expected ]]; then
	exit 0
fi

# Update settings if the port has changed

if [[ -z "$(pgrep -f transmission-gtk)" ]]; then
	exit 1
fi

# Relaunch transmission if it was running
pkill -f transmission-gtk

while [[ -n "$(pgrep -f transmission-gtk)" ]]; do
	sleep .15
done

jq --arg port "$actual" '."peer-port" = $port' "$SETTINGS_PATH" > temp.json && mv temp.json $SETTINGS_PATH

~/Scripts/launch-transmission.sh &>/dev/null &
exit 1
