#! /bin/bash

# Access, enable, or disable hardware prefetchers in Intel processors.

if [ "$#" -eq 1 ] && ( [ "$1" == "-e" ] || [ "$1" == "-enable" ] ); then
    wr=true
    en=true
elif [ "$#" -eq 1 ] && ( [ "$1" == "-d" ] || [ "$1" == "-disable" ] ); then
    wr=true
    en=false
elif [ "$#" -eq 1 ] && ( [ "$1" == "-r" ] || [ "$1" == "-read" ] ); then
    wr=false
else
    echo "Usage: $0 [-r(ead)] [-e(nable)] [-d(isable)]" >&2
    exit 1
fi

# CPU configs.
family=`cat /proc/cpuinfo | grep -m 1 "^cpu family" | cut -d: -f2 | awk '{$1=$1};1'`
model=`cat /proc/cpuinfo | grep -m 1 "^model" | cut -d: -f2 | awk '{$1=$1};1'`
ncpus=`cat /proc/cpuinfo | grep "^processor" | wc -l`
echo "CPU family ${family}, model ${model}, ${ncpus} logic cores"

let "lastcpu = ${ncpus} - 1"

# Test package.
dpkg -s msr-tools >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
    echo "Must install the package msr-tools" >&2
    exit 1
fi
sudo modprobe msr

# Test which msr to use.
# Bit 9 and 19 in msr 0x1a0 for Core and before.
# Bit 0, 1, 2, 3 in msr 0x1a4 for Nehalem and after.
# https://software.intel.com/en-us/articles/optimizing-application-performance-on-intel-coret-microarchitecture-using-hardware-implemented-prefetchers
# https://software.intel.com/en-us/articles/disclosure-of-hw-prefetcher-control-on-some-intel-processors
sudo rdmsr -p 0 0x1a4 >/dev/null 2>&1
if [ "$?" -eq 0 ]; then
    uarch_is_core=false
    msrno=0x1a4
else
    uarch_is_core=true
    msrno=0x1a0
fi
echo "Use MSR ${msrno}"

# Set msr per core.
for cpu in `seq 0 ${lastcpu}`; do
    # Use -d for decimal output.
    msrval=$(sudo rdmsr -p ${cpu} -d ${msrno})
    msrvalold=${msrval}
    if ${wr}; then
        if ${en}; then
            if ${uarch_is_core}; then
                let "msrval &= 0xfff7fdff"
            else
                let "msrval &= 0xfffffff0"
            fi
        else
            if ${uarch_is_core}; then
                let "msrval |= 0x80200"
            else
                let "msrval |= 0xf"
            fi
        fi
        sudo wrmsr -p ${cpu} ${msrno} ${msrval}
    fi
    printf "[core %d] 0x%x --> 0x%x\n" ${cpu} ${msrvalold} ${msrval}
done

