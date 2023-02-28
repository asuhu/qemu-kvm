#!/bin/bash
name=$1
Detachtime=`date "+Instance Detach Time %Y-%m-%d %H:%M.%S"`
DetachISO=`virsh domblklist VM10 | grep 'hda\|sda'`
if [ -z ${name} ];then
	echo -e "\e[1;33;41m Please Input Instance Name. \e[0m"
	echo "bash detach_iso.sh Instance Name."
else
	if virsh domstate ${name} | grep running 2>&1 >/dev/null;then
		 virsh change-media ${name} hda --eject --live --config --force 2>/dev/null
		 virsh change-media ${name} sda --eject --live --config --force 2>/dev/null
		 echo "Successfully detach ${DetachISO}."
		 echo -e "\e[1;33;41m Successfully detach ${DetachISO}. \e[0m"
		 echo "${Detachtime}" "-" "Instance Name ${name}" "-" "${DetachISO}" >>/root/instance.log
	else
		 virsh change-media ${name} hda --eject --config --force 2>/dev/null
		 virsh change-media ${name} sda --eject --config --force 2>/dev/null
		 echo "Successfully detach ${DetachISO}."
		 echo -e "\e[1;33;41m Successfully detach ${DetachISO}. \e[0m"
		 echo "${Detachtime}" "-" "Instance Name ${name}" "-" "${DetachISO}" >>/root/instance.log
	fi
fi