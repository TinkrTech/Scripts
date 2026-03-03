#!/usr/bin/env bash

TIME_FORMAT="%(%F-%H%M)T" # yyyy-mm-dd-HHMM 
declare -A PREFIXES
PREFIXES=(
	[ad-hoc]=""
	[daily]="daily."
	[weekly]="weekly."
	[monthly]="monthly."
)

LOCALS=( 
	"/mnt/data/Backup"
)

REMOTES=(
	"vanasa@10.0.0.99:/mnt/vdev1/Shared/Jade/Backup"
)

