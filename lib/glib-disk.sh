#!/bin/bash

find_device() {
    local list="$*"
    local dev
    for dev in $list; do
        [ -e "$dev" ] && echo "$dev" && break
    done
}

append_disk_part() {
    local dev="$1"
    local part="$2"
    echo "$dev" | grep -q '/nvme[0-9]\+n[0-9]\+$' \
        && echo "${dev}p${part}" || echo "${dev}${part}"
}

find_disk1() {
    local dev=$(find_device /dev/sda /dev/xvda /dev/nvme0n1)
    [ -z "$dev" ] && edie "Unable to find disk 1" || echo "$dev"
}

find_disk2() {
    local dev=$(find_device /dev/sdb /dev/xvdb /dev/nvme1n1)
    [ -z "$dev" ] && edie "Unable to find disk 2" || echo "$dev"
}
