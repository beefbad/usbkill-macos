#!/bin/bash
DIR=$(pwd)
LOGFILE="$DIR/usbkill.log"
SETTINGSFILE="$DIR/settings"

kill_computer(){
	log "Detected usb change. Killing computer..."
	##############################################
	# <<! YOUR "KILL-CODE" HERE !>>
	# Example:
	# killall loginwindow Finder && halt -q
	##############################################
}

listusb(){
	DEVICES=( $(system_profiler SPUSBDataType 2>/dev/null | grep "Product ID:" | awk '{ print $3 }') )
}

log(){
	echo "$(date) $1" >> $LOGFILE
	listusb
	local currentdeviceindicies=${!DEVICES[*]}
	local mydevices=""
	for index in $currentdeviceindicies; do
		mydevices="$mydevices \"${DEVICES[$index]}\""
	done
	echo "Current state: $mydevices" >> $LOGFILE
}

settings_template() {
	if [ ! -f $SETTINGSFILE ]; then
		listusb
		local settings="whitelist=( "
		local currentdeviceindicies=${!DEVICES[*]}
		for index in $currentdeviceindicies; do
			settings="$settings \"${DEVICES[$index]}\" "
		done
		settings="$settings)"
		touch $SETTINGSFILE
		echo $settings >> $SETTINGSFILE
		echo "sleep=1" >> $SETTINGSFILE
	fi
}

load_settings(){
	source "$SETTINGSFILE"
}

containsElement () {
	local e
	for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
	return 1
}

monitor(){
	listusb
	local startdeviceindicies=${!DEVICES[*]}
	for index in $startdeviceindicies; do
		start_devices[$index]=${DEVICES[$index]}
	done
	load_settings
	log "Started patrolling the USB ports every $sleep seconds."
	while true
	do
		listusb
		local currentdeviceindicies=${!DEVICES[*]}
		for index in $currentdeviceindicies; do
			current_devices[$index]=${DEVICES[$index]}
		done
		for i in "${current_devices[@]}"; do
			if [[ ! "${start_devices[@]}" =~ "$i" && ! "${whitelist[@]}" =~ "$i" ]]; then
				kill_computer
			fi
		done
		for i in "${start_devices[@]}"; do
			if [[ ! "${current_devices[@]}" =~ "$i" ]]; then
				kill_computer
			fi
		done
		current_devices=( )
		sleep $sleep
	done
}

signaled(){
	log "Exiting because exit signal was received"
	exit 0
}

if [[ $EUID != 0 ]]; then
	echo "This program needs to run as root."
	exit 1
fi
if [ ! -f $LOGFILE ]; then
	touch $LOGFILE
fi
settings_template
trap signaled SIGHUP SIGINT SIGTERM SIGQUIT
monitor