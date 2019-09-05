#!/bin/bash
#$1数字，代表虚拟机的名字
name=$1
if virsh domstate ${name} | grep running;then
 virsh change-media ${name} hda --eject --live --config --force 2>/dev/null
 virsh destroy ${name}
 virsh undefine ${name} --snapshots-metadata --remove-all-storage
else
 virsh change-media ${name} hda --eject --config --force 2>/dev/null
 virsh undefine ${name} --snapshots-metadata --remove-all-storage
fi

bash -x delete.sh VM20