#!/bin/sh
# Facts for the System section, one key=value per line.
#   system.sh static   facts that do not change while the shell runs
#   system.sh live     values the section refreshes every 2 s

# The GPU the section shows: NVIDIA when its driver is loaded, else an AMD
# card (it reports its own load), else none.
amd_card() {
    for card in /sys/class/drm/card*; do
        [ -f "$card/device/gpu_busy_percent" ] && echo "$card" && return
    done
}

# First temperature from a sensor with one of the given names.
hwmon_temp() {
    for hwmon in /sys/class/hwmon/hwmon*; do
        name=$(cat "$hwmon/name" 2>/dev/null)
        for wanted in "$@"; do
            [ "$name" = "$wanted" ] && cat "$hwmon/temp1_input" && return
        done
    done
}

static() {
    echo "host=$(cat /proc/sys/kernel/hostname)"
    . /etc/os-release && echo "os=$PRETTY_NAME"
    echo "arch=$(uname -m)"
    echo "kernel=$(uname -r)"

    # elogind also makes /run/systemd, so look for systemd/system.
    if [ -d /run/systemd/system ]; then init=systemd
    elif [ -d /run/openrc ]; then init=openrc
    elif [ -d /run/runit ]; then init=runit
    elif [ -d /run/s6 ]; then init=s6
    elif [ -e /run/dinitctl ]; then init=dinit
    else init=$(ps -p 1 -o comm=)
    fi
    echo "init=$init"

    echo "hyprland=$(hyprctl version -j | sed -n 's/.*"version": "\(.*\)".*/\1/p' | head -n 1)"
    echo "quickshell=$(qs --version | cut -d' ' -f2)"
    core=$(ldd "$(command -v qs)" | grep -o '/[^ ]*libQt6Core\.so[^ ]*')
    echo "qt=$(readlink -f "$core" | sed 's/.*\.so\.//')"

    echo "cpu=$(grep -m 1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/(R)//g; s/(TM)//g; s/ CPU//; s/ @.*//; s/^ *//')"
    echo "cores=$(lscpu -p=core | grep -v '^#' | sort -u | wc -l)"
    echo "threads=$(nproc)"

    # "... controller: Vendor Chip [Marketing name] (rev a1)": keep the
    # marketing name when there is one.
    if [ -d /sys/bus/pci/drivers/nvidia ]; then
        line=$(lspci | grep -iE 'vga|3d' | grep -i nvidia | head -n 1)
    elif [ -n "$(amd_card)" ]; then
        line=$(lspci | grep -iE 'vga|3d|display' | grep -iE 'amd|ati' | head -n 1)
    else
        line=$(lspci | grep -iE 'vga|3d|display' | head -n 1)
    fi
    name=$(echo "$line" | sed 's/ (rev .*//; s/.*: //')
    case "$name" in
        *\[*\]*) name=$(echo "$name" | sed 's/.*\[\(.*\)\].*/\1/') ;;
    esac
    echo "gpu=$name"
}

live() {
    echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
    echo "cpustat=$(head -n 1 /proc/stat)"
    echo "cputemp=$(hwmon_temp coretemp k10temp zenpower)"

    awk '/^MemTotal:/ { print "memtotal=" $2 } /^MemAvailable:/ { print "memavailable=" $2 }' /proc/meminfo

    # nvidia-smi wakes a suspended card and costs battery, so skip it then.
    if [ -d /sys/bus/pci/drivers/nvidia ]; then
        if [ "$(cat /sys/bus/pci/drivers/nvidia/*/power/runtime_status 2>/dev/null | head -n 1)" = suspended ]; then
            echo "gpustate=suspended"
        else
            nvidia-smi --format=csv,noheader,nounits --query-gpu=utilization.gpu,temperature.gpu \
                | head -n 1 | awk -F', ' '{ print "gpuusage=" $1; print "gputemp=" $2 * 1000 }'
        fi
    else
        card=$(amd_card)
        if [ -n "$card" ]; then
            echo "gpuusage=$(cat "$card/device/gpu_busy_percent")"
            echo "gputemp=$(hwmon_temp amdgpu)"
        fi
    fi

    df -B1 --output=used,size,fstype / | tail -n 1 \
        | awk '{ print "diskused=" $1; print "disksize=" $2; print "diskfs=" $3 }'

    battery=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)
    if [ -n "$battery" ]; then
        echo "battery=$(cat "$battery/capacity")"
        echo "batterystatus=$(cat "$battery/status")"
        # Energy (µWh, µW) on most laptops, charge (µAh, µA) on some.
        echo "batterynow=$(cat "$battery/energy_now" "$battery/charge_now" 2>/dev/null | head -n 1)"
        echo "batteryfull=$(cat "$battery/energy_full" "$battery/charge_full" 2>/dev/null | head -n 1)"
        echo "batteryrate=$(cat "$battery/power_now" "$battery/current_now" 2>/dev/null | head -n 1)"
    fi
}

"$1"
