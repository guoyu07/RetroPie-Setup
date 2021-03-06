#!/usr/bin/env bash
AUDIO="$1"
ROM="$2"
rootdir="/opt/retropie"
configdir="$rootdir/configs"

source "$rootdir/lib/inifuncs.sh"

function mapInput() {
    local js_device
    local js_device_num
    local ev_device
    local ev_devices
    local ev_device_num
    local device_counter
    local conf="$configdir/dreamcast/emu.cfg"
    local params=""

    # get a list of all present js device numbers and device names
    # and device count
    for js_device in /dev/input/js*; do
        js_device_num=${js_device/\/dev\/input\/js/}
        for ev_device in /dev/input/event*; do
            ev_device_num=${ev_device/\/dev\/input\/event/}
            if [[ -d "/sys/class/input/event${ev_device_num}/device/js${js_device_num}" ]]; then
                file[$ev_device_num]=$(grep --exclude=*.bak -rl "$configdir/dreamcast/mappings/" -e "= $(</sys/class/input/event${ev_device_num}/device/name)")
                if [[ -f "${file[$ev_device_num]}" ]]; then
                    #file[$ev_device_num]="${file[$ev_device_num]##*/}"
                    ev_devices[$ev_device_num]=$(</sys/class/input/event${ev_device_num}/device/name)
                    device_counter=$(($device_counter+1))
                fi
            fi
        done
    done

    # emu.cfg: store up to four event devices and mapping files
    if [[ "$device_counter" -gt "0" ]]; then
        # reicast supports max 4 event devices
        if [[ "$device_counter" -gt "4" ]]; then
            device_counter="4"
        fi
        local counter=0
        for ev_device_num in "${!ev_devices[@]}"; do
            if [[ "$counter" -lt "$device_counter" ]]; then
                counter=$(($counter+1))
                params+="-config input:evdev_device_id_$counter=$ev_device_num "
                params+="-config input:evdev_mapping_$counter=${file[$ev_device_num]} "
            fi
        done
        while [[ "$counter" -lt "4" ]]; do
            counter=$(($counter+1))
            params+="-config input:evdev_device_id_$counter=-1 "
            params+="-config input:evdev_mapping_$counter=-1 "
        done
    else
        # fallback to keyboard setup
        params+="-config input:evdev_device_id_1=0 "
    fi
    params+="-config input:joystick_device_id=-1 "
    params+="-config players:nb=$device_counter "
    echo "$params"
}

if [[ -f "$HOME/RetroPie/BIOS/dc_boot.bin" ]]; then
    params="-config config:homedir=$HOME -config x11:fullscreen=1 "
    getAutoConf reicast_input && params+=$(mapInput)
    params+=" -config audio:backend=$AUDIO -config audio:disable=0 "
    if [[ "$AUDIO" == "oss" ]]; then
        aoss "$rootdir/emulators/reicast/bin/reicast" $params -config config:image="$ROM" >> /dev/null
    else
        "$rootdir/emulators/reicast/bin/reicast" $params -config config:image="$ROM" >> /dev/null
    fi
else
    dialog --msgbox "You need to copy the Dreamcast BIOS files (dc_boot.bin and dc_flash.bin) to the folder $biosdir to boot the Dreamcast emulator." 22 76
fi
