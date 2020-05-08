#!/bin/bash
name=$1
if virsh domstate ${name} | grep running;then
 virsh change-media ${name} hda --eject --live --config --force 2>/dev/null
 virsh change-media ${name} sda --eject --live --config --force 2>/dev/null
 virsh destroy ${name}
 virsh undefine ${name} --snapshots-metadata --remove-all-storage --nvram
else
 virsh change-media ${name} hda --eject --config --force 2>/dev/null
 virsh change-media ${name} sda --eject --config --force 2>/dev/null
 virsh undefine ${name} --snapshots-metadata --remove-all-storage --nvram
fi
