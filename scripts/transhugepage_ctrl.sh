#! /bin/bash

# Turn on or off Transparent Huge Pages (THP).

# https://stackoverflow.com/questions/44800633/how-to-disable-transparent-huge-pages-thp-in-ubuntu-16-04lts
# https://www.stephenrlang.com/2018/01/disabling-transparent-huge-pages-in-linux/

if [ "$#" -eq 1 ] && [ "$1" == "on" ]; then
    en=true
elif [ "$#" -eq 1 ] && [ "$1" == "off" ]; then
    en=false
else
    echo "Usage: $0 [on] [off]" >&2
    exit 1
fi

# Check if hugeadm is installed (package hugepages)
if type hugeadm >/dev/null 2>&1; then
    # Use hugeadm
    if ${en}; then
        hugeadm --thp-madvise
    else
        hugeadm --thp-never
    fi
else
    # Directly write to /sys
    if ${en}; then
        echo "madvise" > /sys/kernel/mm/transparent_hugepage/enabled
        echo "always" > /sys/kernel/mm/transparent_hugepage/defreg
    else
        echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
        echo "never" > /sys/kernel/mm/transparent_hugepage/defreg
    fi
fi

