# qemu-kvm
<ol>
 KVM environment, support for Ceph rbd block storage, support for upgrading Qemu, support for upgrading libvirt<br />
 一键安装KVM环境，支持Ceph rbd块存储，支持升级Qemu，支持升级libvirt<br />
<li>需要服务器支持虚拟化技术Virtualization Technological</li>
<li>tuned-adm profile virtual-host   #Optimize for running KVM guests</li>
<li>chmod +x install_kvm_rbd_upgradeqemu_upgradelibvurt.sh</li>
</ol>
 <hr />
    <ol>
 创建虚拟机<br />
<li>创建CentOS6</li>
    bash -x centos6.sh $1 $2 $3 $4    (name Memory CpuCont  DiskSize)<br />
<li>创建CentOS7</li>
    bash -x centos7.sh $1 $2 $3 $4    (name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2008R2</li>
    bash -x win2k8r2.sh $1 $2 $3 $4     (name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2012R2</li>
    bash -x win2k12r2.sh $1 $2 $3 $4    (name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2016</li>
    bash -x win2k16.sh $1 $2 $3 $4      (name Memory CpuCont  DiskSize)<br />
    </ol>
 <hr />
<ol>
 彻底摧毁虚拟机
<li>bash -x delete.sh $1   (delete.sh name)</li>
</ol>
  
 
 
