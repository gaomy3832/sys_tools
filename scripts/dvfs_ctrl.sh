#! /bin/bash

# Control DVFS.

gov=0
freq=0
while [[ "$#" -gt 0 ]]; do
    key=$1
    case ${key} in
        -g)
            gov="$2"
            shift; shift  # past opt and value
            ;;
        -f)
            freq="$2"
            shift; shift  # past opt and value
            ;;
        *)
            echo "Usage: $0 [-g <governor>] [-f frequency]" >&2
            exit 1
            ;;
    esac
done
if [ "${gov}" != "0" ] && [ "${freq}" != "0" ]; then
    echo "Cannot specify both governor and frequency" >&2
    exit 1
fi
([ "${gov}" != "0" ] || [ "${freq}" != "0" ]) && wr=true || wr=false


# CPU configs.
family=`cat /proc/cpuinfo | grep -m 1 "^cpu family" | cut -d: -f2 | awk '{$1=$1};1'`
model=`cat /proc/cpuinfo | grep -m 1 "^model" | cut -d: -f2 | awk '{$1=$1};1'`
ncpus=`cat /proc/cpuinfo | grep "^processor" | wc -l`
echo "CPU family ${family}, model ${model}, ${ncpus} logic cores"

let "lastcpu = ${ncpus} - 1"

# Subroutines for state probe.
get_gov() {
    local c=$1
    echo `cat /sys/devices/system/cpu/cpu${c}/cpufreq/scaling_governor`
}

get_freq() {
    local c=$1
    echo `cat /sys/devices/system/cpu/cpu${c}/cpufreq/scaling_cur_freq`
}

# Set governor and frequency per core.
for cpu in `seq 0 ${lastcpu}`; do
    # Use -d for decimal output.
    printf "[core %2d] gov %s, freq %d" ${cpu} `get_gov ${cpu}` `get_freq ${cpu}`
    if ${wr}; then
        if [ "${gov}" != "0" ]; then
            args=" -g ${gov}"
        elif [ "${freq}" != "0" ]; then
            args=" -f ${freq}"
        fi
        # Alternatively, we can do this by directly writing to scaling_governor
        # and scaling_setspeed files. Note that to write scaling_setspeed, we
        # must first set scaling_governor to be userspace.
        sudo cpupower -c ${cpu} frequency-set ${args} > /dev/null 2>&1 &&
            printf " -> gov %s, freq %d" `get_gov ${cpu}` `get_freq ${cpu}` ||
            printf " (failed)"
    fi
    printf "\n"
done

