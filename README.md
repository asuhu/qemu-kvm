# qemu-kvm

<h2>KVM environment, support for Ceph rbd block storage, support for upgrading Qemu, support for upgrading libvirt, support for upgrading nested<br /> </h2>
 <ol>
<li>需要服务器支持虚拟化技术Virtualization Technological</li>
<li>支持选择是否升级Qemu</li>
<li>支持选择是否升级libvirt</li>
<li>支持选择是否启用虚拟化嵌套nested</li>
<li>tuned-adm profile virtual-host   #Optimize for running KVM guests</li>
<li>--video virtio   #支持高分辨率https://libvirt.org/formatdomain.html#elementsVideo</li>
<li>--boot uefi,cdrom,hd,network,menu=on   #UEFI 启动（需要升级qemu-kvm，安装OVMF）</li>
<li>--machine 默认为pc(alias of pc-i440fx-4.2)，--machine q35   #Standard PC (Q35 + ICH9, 2009) (alias of pc-q35-4.2)</li>
<li>--features kvm_hidden=on  #Allow the KVM hypervisor signature to be hidden from the guest</li>
<li>--vcpus sockets=${SocketNU},cores=${CoreNU},threads=${ThreadNU}  #vCPU = sockets * cores * threads</li>
</ol>
 <hr />
 
 <h2>创建虚拟机<br /></h2>
     <ol>
<li>创建CentOS6</li>
    bash -x centos6.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
<li>创建CentOS7</li>
    bash -x centos7.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
    例子 bash -x centos7.sh 7 1024 4 40，创建名称为7、内存为1024M、4核心CPU、40G磁盘的instance<br />
<li>创建Windows Server 2008R2</li>
    bash -x win2k8r2.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2012R2</li>
    bash -x win2k12r2.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2016</li>
    bash -x win2k16.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
    <li>创建Windows Server 2019</li>
    bash -x win2k19.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
    <li>创建Windows Server 2019 UEFI</li>
    bash -x win2k19uefi.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
    <li>创建Windows Server 2019 CPU</li>
    bash -x win2k19cpu.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;$5&nbsp;$6&nbsp;&nbsp;(name Memory sockets cores  threads DiskSize)<br />
    例子 bash -x win2k19cpu.sh 9 4096 1 2 2 200，创建名称为9、内存为4096M、1插槽2核心2线程共4核心CPU、200G磁盘的instance<br />
    </ol>
 <hr />

  <h2>彻底摧毁虚拟机</h2>
 <ol>
<li>bash -x delete.sh&nbsp;$1&nbsp;&nbsp;&nbsp;&nbsp;(delete.sh name)</li>
</ol>
    <h2>升级后的版本</h2>
 <img src="https://raw.githubusercontent.com/asuhu/qemu-kvm/master/kvm.png"  alt="virsh version" />