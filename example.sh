1、网络部分

#修改网卡1  ifcfg-enp97s0f0
vim /etc/sysconfig/network-scripts/ifcfg-enp97s0f0
DEVICE=enp97s0f0
USERCTL=no
ONBOOT=yes
MASTER=bond6
SLAVE=yes
BOOTPROTO=none

#修改网卡2  ifcfg-enp97s0f1
#vim /etc/sysconfig/network-scripts/ifcfg-enp97s0f1
DEVICE=enp97s0f1
USERCTL=no
ONBOOT=yes
MASTER=bond6
TYPE=Ethernet
SLAVE=yes
BOOTPROTO=none


#bond6 配置
#vim /etc/sysconfig/network-scripts/ifcfg-bond6
改成如下
DEVICE=bond6
NAME=bond6
TYPE=Bond
USERCTL=no
BOOTPROTO=none
ONBOOT=yes
BONDING_MASTER=yes
BONDING_OPTS="mode=6 miimon=100"
BRIDGE=br0

#配置桥接 br0
#vim /etc/sysconfig/network-scripts/ifcfg-br0
DEVICE=br0
NAME=br0
TYPE=Bridge
BOOTPROTO=static
IPADDR=10.53.220.115
NETMASK=255.255.255.0
GATEWAY=10.53.220.1
DNS1=114.114.114.114
DNS1=223.5.5.5
ONBOOT=yes


2、创建文件夹
/data/iso/

3、上传镜像
cd /data/iso/

4、vGPU部分
安装vGPU驱动
#rpm -ivh NVIDIA-vGPU-rhel-7.9-460.73.02.x86_64.rpm 

通过检查内核加载模块列表中的 VFIO 驱动程序，验证NVIDIA vGPU软件包是否已正确安装和加载
# lsmod | grep vfio

检查nvidia-vgpu-mgr.service 服务是否正在运行
#systemctl status nvidia-vgpu-mgr.service

检查vGPU驱动是否完成成功
#nvidia-smi

查看支持的vGPU型号
# nvidia-smi vgpu -s

查看mdev_bus
#ls /sys/class/mdev_bus/
0000:3d:00.0  0000:3e:00.0  0000:40:00.0  0000:41:00.0  0000:b1:00.0  0000:b2:00.0  0000:b4:00.0  0000:b5:00.0

# 创建 vGPU 设备 
ls /sys/bus/pci/devices/0000:3d:00.0/mdev_supported_types/
[root@kvm mdev_supported_types]# cd /sys/bus/pci/devices/0000:3d:00.0/mdev_supported_types/nvidia-233

#第一个vGPU设备
# uuidgen
844d691c-a9d8-4845-b288-b81b99b88ae6
# echo "844d691c-a9d8-4845-b288-b81b99b88ae6" > create

# CentOS7 持久化vGPU设备
chmod +x /etc/rc.local
vi /etc/rc.local  #编辑/etc/rc.local
echo "844d691c-a9d8-4845-b288-b81b99b88ae6" > /sys/bus/pci/devices/0000:3e:00.0/mdev_supported_types/nvidia-233/create



# virsh detach-device VM10 add.xml --config
Device detached successfully

# virsh attach-device VM10 add.xml --config
Device attached successfully