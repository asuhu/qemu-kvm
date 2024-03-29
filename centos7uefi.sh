#!/bin/bash
#$1数字，代表名字
#$2数字，代表内存，大小是M
#$3数字，代表cpu的核心数
#$4数字，代表磁盘大小
#osinfo-query os
#bash centos7uefi.sh 10 16384 8 1000
if [ ! -e /data/iso/centos7.iso ];then
	wget -O /data/iso/centos7.iso https://mirrors.aliyun.com/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso
fi
if [ $? -gt 0 ];then
	wget -O /data/iso/centos7.iso  http://arv.asuhu.com/ftp/isos/CentOS-7-x86_64-Minimal-1908.iso
fi
#
number=$1
port=$[5900+$number]
mem=$2
cont=$3
Disksize=$4
createtime=`date "+Instance Create Time %Y-%m-%d %H:%M.%S"`
vncpass=$(date +%s%N | sha256sum | base64 | head -c 15)

#bridging
if brctl show | grep -v vir | grep br0;then
	virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
	--description  "centos7" \
	--network bridge=br0,model=virtio \
	--cdrom /data/iso/centos7.iso \
	--input tablet,bus=usb \
	--machine q35 \
	--features kvm_hidden=on \
	--boot uefi,cdrom,hd,network,menu=on \
	--disk path=/data/image/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2 \
	--graphics vnc,listen=0.0.0.0,port="${port}",keymap=en-us,password="${vncpass}" --noautoconsole \
	--os-type=linux --os-variant=rhel7 --video virtio \
	--clock offset=utc \
	--debug --force --autostart
else
#Network NAT
	virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
	--description  "centos7" \
	--network network=default,model=virtio \
	--cdrom /data/iso/centos7.iso \
	--input tablet,bus=usb \
	--machine q35 \
	--features kvm_hidden=on \
	--boot uefi,cdrom,hd,network,menu=on \
	--disk path=/data/image/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2 \
	--graphics vnc,listen=0.0.0.0,port="${port}",keymap=en-us,password="${vncpass}" --noautoconsole \
	--os-type=linux --os-variant=rhel7 --video virtio \
	--clock offset=utc \
	--debug --force --autostart
fi
#
if [ $? -eq 0 ];then
echo "Instance Name VM${number}" "-" VNC Port ${port} "-" VNC Password ${vncpass}
echo "${createtime}" "-" "Instance Name VM${number}" "-" VNC Port ${port} "-" VNC Password ${vncpass} >>/root/instance.log
  else
echo "Error,Check It."
fi
