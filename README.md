# qemu-kvm
 KVM environment, support for Ceph rbd block storage, support for upgrading Qemu, support for upgrading libvirt<br />
 一键安装KVM环境，支持Ceph rbd块存储，支持升级Qemu，支持升级libvirt<br />
 1、需要服务器支持虚拟化技术Virtualization Technological<br />
 2、tuned-adm profile virtual-host   #Optimize for running KVM guests<br />
 3、chmod +x install_kvm_rbd_upgradeqemu_upgradelibvurt.sh<br />
 <hr />
 创建虚拟机
 1、创建CentOS6<br />
    bash -x centos6.sh $1 $2 $3 $4    (name Memory CpuCont  DiskSize)<br />
 2、创建CentOS7<br />
    bash -x centos7.sh $1 $2 $3 $4    (name Memory CpuCont  DiskSize)<br />
 3、创建Windows Server 2008R2<br />
    bash -x win2k8r2.sh $1 $2 $3 $4     (name Memory CpuCont  DiskSize)<br />
 4、创建Windows Server 2012R2<br />
    bash -x win2k12r2.sh $1 $2 $3 $4    (name Memory CpuCont  DiskSize)<br />
 5、创建Windows Server 2016<br />
    bash -x win2k16.sh $1 $2 $3 $4      (name Memory CpuCont  DiskSize)<br />
 <hr />
 彻底摧毁虚拟机
1、bash -x delete.sh $1   (delete.sh name)<br />
  
 
 
