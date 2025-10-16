#!/bin/bash
#$1数字，代表名字
#$2数字，代表内存，大小是M
#$3数字，代表cpu的核心数
#$4数字，代表磁盘大小
vncpass=$(date +%s%N | sha256sum | base64 | head -c 15)
#bash -x 75_create_win2k19.sh 19 16384 16 1000
number=$1
port=$[5900+$number]
mem=$2
cont=$3
Disksize=$4

#bridging
if brctl show | grep -v vir | grep br0;then
virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
	--network bridge=br0,model=virtio \
	--cdrom /data/iso/2019.iso \
	--input tablet,bus=usb \
	--features kvm_hidden=on \
	--boot cdrom,hd,network,menu=on \
	--serial file,path=/data/"VM${number}"console.log \
	--disk path=/data/instance/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2 \
	--graphics vnc,listen=0.0.0.0,port="${port}",keymap=en-us,password="${vncpass}" --noautoconsole \
	--os-type=windows --os-variant=win2k19 --video virtio \
	--clock offset=localtime,hypervclock_present=yes \
	--debug --force --autostart
else
#Network NAT
virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
	--network network=default,model=virtio \
	--cdrom /data/iso/2019.iso \
	--input tablet,bus=usb \
	--features kvm_hidden=on \
	--boot cdrom,hd,network,menu=on \
	--serial file,path=/data/"VM${number}"console.log \
	--disk path=/data/instance/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2 \
	--graphics vnc,listen=0.0.0.0,port="${port}",keymap=en-us,password="${vncpass}" --noautoconsole \
	--os-type=windows --os-variant=win2k19 --video virtio \
	--clock offset=localtime,hypervclock_present=yes \
	--debug --force --autostart
fi
#osinfo-query os
if [ $? -eq 0 ];then
echo "Instance Name VM${number}" "-" VNC Port ${port} "-" VNC Password ${vncpass}
echo "${createtime}" "-" "Instance Name VM${number}" "-" VNC Port ${port} "-" VNC Password ${vncpass} >>/root/instance.log
  else
echo "Error,Check It."
fi