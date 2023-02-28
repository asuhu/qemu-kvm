#!/bin/bash
name=$1
iso=$2
Attachtime=`date "+Instance Attach Time %Y-%m-%d %H:%M.%S"`
if [ -z ${name} ];then
	echo -e "\e[1;33;41m Please Input Instance Name. \e[0m"
	echo "bash attach_iso.sh Instance Name ISO Name."
else
		virsh attach-disk ${name} ${iso} sda --type cdrom --mode readonly
		 echo -e "\e[1;33;41m ${name} Successfully attach ${iso}. \e[0m"
		 echo "${Attachtime}" "-" "Instance Name ${name}" "-" "${iso}" >>/root/instance.log
fi