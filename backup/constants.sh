#!/usr/bin/env bash

TIME_FORMAT="%(%F-%H%M)T"
declare -A PREFIXES
PREFIXES=(
	[adHoc]=""
	[daily]="daily."
	[weekly]="weekly."
	[monthly]="monthly."
)

LOCALS=( 
	"/mnt/data/backup"
)

REMOTES=(
	"vanasa@10.0.0.99:/mnt/vdev1/Shared/Jade/Backup"
)

