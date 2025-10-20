#!/bin/bash
#$1 数字，代表名字
#$2 数字，代表内存，大小是M
#$3 数字，代表CPU核心数
#$4 数字，代表磁盘大小
# 使用示例: bash centos8.sh 10 16384 16 1000
#qemu-system-x86_64 --help  | grep -i "aio="
#       [,aio=threads|native|io_uring]  如果 QEMU 和 Linux 内核版本支持 io_uring，强烈建议用 io_uring，性能最优

number=$1
port=$((5900 + number))
mem=$2
cont=$3
Disksize=$4
createtime=$(date "+Instance Create Time %Y-%m-%d %H:%M.%S")
vncpass=$(date +%s%N | sha256sum | base64 | head -c 15)

# ===== 判断是否存在 br0 桥接 =====
BRIDGE_EXISTS=$(brctl show 2>/dev/null | grep -v vir | grep br0 || true)

# ===== 创建虚拟机 =====
if [ -n "$BRIDGE_EXISTS" ]; then
    # 使用桥接网络
    virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
        --description "centos8" \
        --network bridge=br0,model=virtio \
        --cdrom /data/iso/Kylin-Server-V10.iso \
        --input tablet,bus=usb \
        --machine q35 \
        --features kvm_hidden=on \
        --boot cdrom,hd,network,menu=on \
        --disk path=/data/instance/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2,aio=io_uring \
        --graphics vnc,listen=0.0.0.0,port="${port}",keymap=en-us,password="${vncpass}" --noautoconsole \
        --os-type=linux --os-variant=centos8 --video virtio \
        --clock offset=utc \
        --debug --force --autostart
else
    # 使用 NAT 网络
    virt-install --virt-type kvm --name "VM$number" --ram="$mem" --vcpus="$cont" --cpu=host-passthrough --accelerate --hvm \
        --description "centos8" \
        --network network=default,model=virtio \
        --cdrom /data/iso/Kylin-Server-V10.iso \
        --input tablet,bus=usb \
        --machine q35 \
        --features kvm_hidden=on \
        --boot cdrom,hd,network,menu=on \
        --disk path=/data/instance/"VM$number".qcow2,size="${Disksize}",bus=virtio,cache=writeback,sparse=true,format=qcow2,aio=io_uring \
        --graphics vnc,listen=0.0.0.0,port="${port}",keymap=en-us,password="${vncpass}" --noautoconsole \
        --os-type=linux --os-variant=centos8 --video virtio \
        --clock offset=utc \
        --debug --force --autostart
fi

# ===== 输出结果 =====
if [ $? -eq 0 ]; then
    echo "Instance Name VM${number} - VNC Port ${port} - VNC Password ${vncpass}"
    echo "${createtime} - Instance Name VM${number} - VNC Port ${port} - VNC Password ${vncpass}" >> /root/instance.log
else
    echo "Error, Check It."
fi