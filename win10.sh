#!/bin/bash
#$1数字，代表名字
#$2数字，代表内存，大小是M
#$3数字，代表cpu的核心数
#$4数字，代表磁盘大小
vncpass=$(date +%s%N | sha256sum | base64 | head -c 15)

number=$1
port=$[5900+$number]
mem=$2
cont=$3
Disksize=$4

#bridging
if brctl show | grep -v vir | grep br0;then
virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
--network bridge=br0,model=virtio \
--cdrom /data/iso/10.iso \
--input tablet,bus=usb \
--machine q35 \
--features kvm_hidden=on \
--boot cdrom,hd,network,menu=on \
--serial file,path=/data/"VM${number}"console.log \
--disk path=/data/image/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2 \
--graphics vnc,listen=0.0.0.0,port="$port",password="${vncpass}" --noautoconsole --os-type=windows --os-variant=win10 --video virtio \
--debug --clock offset=localtime --force --autostart
else
#Network NAT
virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
--network network=default,model=virtio \
--cdrom /data/iso/10.iso \
--input tablet,bus=usb \
--machine q35 \
--features kvm_hidden=on \
--boot cdrom,hd,network,menu=on \
--serial file,path=/data/"VM${number}"console.log \
--disk path=/data/image/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2 \
--graphics vnc,listen=0.0.0.0,port="$port",password="${vncpass}" --noautoconsole --os-type=windows --os-variant=win10 --video virtio \
--debug --clock offset=localtime --force --autostart
fi
#osinfo-query os
echo "VM$number" , vnc port ${port} , vnc password ${vncpass}
