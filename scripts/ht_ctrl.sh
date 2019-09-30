#! /bin/bash

# Turn on or off hyperthreading in Intel processors.

if [ "$#" -eq 1 ] && [ "$1" == "on" ]; then
    en=true
elif [ "$#" -eq 1 ] && [ "$1" == "off" ]; then
    en=false
else
    echo "Usage: $0 [on] [off]" >&2
    exit 1
fi

# CPU configs.
family=`cat /proc/cpuinfo | grep -m 1 "^cpu family" | cut -d: -f2 | awk '{$1=$1};1'`
model=`cat /proc/cpuinfo | grep -m 1 "^model" | cut -d: -f2 | awk '{$1=$1};1'`
echo "CPU family ${family}, model ${model}"

ncpus=`cat /proc/cpuinfo | grep "^processor" | wc -l`
echo "Before: ${ncpus} logic cores online"

cputop=/sys/devices/system/cpu

# `update c 1/0`: update core `c` to online/offline.
update () {
    local c=$1
    local new=$2
    local cpuonlinefile=${cputop}/cpu${c}/online
    local old=`cat ${cpuonlinefile} 2>/dev/null || echo 0`
    if [ "${new}" != "${old}" ]; then
        echo "[core ${c}] ${old} --> ${new}"
        sudo bash -c "echo ${new} > ${cpuonlinefile}"
    fi
}

for cpudir in `ls -d ${cputop}/cpu[[:digit:]]*`; do
    cpu=${cpudir##*/cpu}

    # Core 0 cannot be turned off, nor does online file exist.
    if [ "${cpu}" -eq 0 ]; then continue; fi

    if ${en}; then
        update ${cpu} 1
    else
        siblistfile=${cpudir}/topology/thread_siblings_list
        if [ ! -f "${siblistfile}" ]; then
            # Only look at online cores. If not existing, already offline.
            continue
        fi
        siblist=`cat ${siblistfile} | awk -F, '{$1=$1};1'`

        # Turn off all siblings except the minimum one.
        min=${siblist%% *}
        for sib in ${siblist}; do
            if [ "${sib}" -lt "${min}" ]; then
                update ${min} 0
                min=${sib}
            elif [ "${sib}" -gt "${min}" ]; then
                update ${sib} 0
            fi
        done
    fi
done

ncpus=`cat /proc/cpuinfo | grep "^processor" | wc -l`
echo "After: ${ncpus} logic cores online"

