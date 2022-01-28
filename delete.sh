#!/bin/bash
name=$1
deletetime=`date "+Instance Delete Time %Y-%m-%d %H:%M.%S"`
if [ -z ${name} ];then
	echo -e "\e[1;33;41m Please Input Instance Name. \e[0m"
	echo "bash delete.sh Instance Name."
else
	if virsh domstate ${name} | grep running 2>&1 >/dev/null;then
		 virsh change-media ${name} hda --eject --live --config --force 2>/dev/null
		 virsh change-media ${name} sda --eject --live --config --force 2>/dev/null
		 virsh destroy ${name} 2>&1 >/dev/null
		 virsh undefine ${name} --snapshots-metadata --remove-all-storage --nvram
		 echo "Successfully delete ${name}."
		 echo -e "\e[1;33;41m Successfully delete ${name}. \e[0m"
		 echo "${deletetime}" "-" "Instance Name ${name}" >>/root/instance.log
	else
		 virsh change-media ${name} hda --eject --config --force 2>/dev/null
		 virsh change-media ${name} sda --eject --config --force 2>/dev/null
		 virsh undefine ${name} --snapshots-metadata --remove-all-storage --nvram
		 echo "${deletetime}" "-" "Instance Name ${name}" >>/root/instance.log
	fi
fi