<h2>Introduction 简介</h2>
 <ol>
<li>KVM environment</li>
<li>upgrading Qemu(support Ceph rbd block storage) </li>
<li>upgrading libvirt</li>
<li>configure nested</li>
<li>configure OVMF UEFI</li>
<li>configure PCI_Passthrough</li>

</ol>
 <hr />
<h2>Installation Instructions 安装须知</h2>
 <ol>
<li>需要服务器支持虚拟化技术 Virtualization Technological</li>
<li>支持选择是否升级Qemu(support Ceph rbd block storage)</li>
<li>支持选择是否升级libvirt</li>
<li>支持选择是否配置虚拟化嵌套nested</li>
<li>支持选择是否配置OVMF UEFI</li>
<li>支持选择是否配置PCI直通PCI_Passthrough</li>
<li>error: Operation not supported: internal snapshots of a VM with pflash based firmware are not supported
在启用uefi和使用snapshot功能之间要自行权衡后选择使用，或者存储支持快照的特性（ceph）</li>
<li>tuned-adm profile virtual-host   #Optimize for running KVM guests</li>
<li>--video virtio   #支持高分辨率https://libvirt.org/formatdomain.html#elementsVideo</li>
<li>--boot uefi,cdrom,hd,network,menu=on   #UEFI 启动（需要升级qemu-kvm，安装OVMF）</li>
<li>--machine 默认为pc(alias of pc-i440fx-4.2)，--machine q35   #Standard PC (Q35 + ICH9, 2009) (alias of pc-q35-4.2)</li>
<li>--features kvm_hidden=on  #Allow the KVM hypervisor signature to be hidden from the guest</li>
<li>--vcpus sockets=${SocketNU},cores=${CoreNU},threads=${ThreadNU}  #vCPU = sockets * cores * threads</li>
</ol>
 <hr />
  <h2>Install 安装<br /></h2>
  bash install_kvm_rbd_upgradeqemu_upgradelibvurt.sh 2>&1 | tee kvm.log
 <hr />
 <h2>Create instance 创建虚拟机<br /></h2>
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
    例子 bash -x win2k19cpu.sh 9 4096 1 2 2 200，创建名称为9、内存为4096MB、1插槽(socket)2核心(cores)2线程共4核心CPU、200G磁盘的instance<br />
    </ol>
 <hr />
  <h2>Undefine instance 彻底摧毁虚拟机</h2>
 <ol>
<li>bash -x delete.sh&nbsp;$1&nbsp;&nbsp;&nbsp;&nbsp;(delete.sh instance name)</li>
      bash -x delete.sh VM6，彻底摧毁名字为VM6的instance<br />
</ol>
 <hr />
   <h2>Detach Attach ISO 卸载和挂载ISO</h2>
 <ol>
 <li>bash -x detach_iso.sh&nbsp;$1&nbsp;&nbsp;&nbsp;&nbsp;(detach_iso.sh instance name)</li>
      bash -x detach_iso.sh VM6，彻底卸载名字为VM6的instance的ISO镜像<br />
<li>bash -x attach_iso.sh&nbsp;$1&nbsp;$2&nbsp;&nbsp;&nbsp;&nbsp;(attach_iso instance name iso address)</li>
      bash -x attach_iso.sh VM6 /nfs/iso/windows_server_2016_virtio.iso，临时挂载名字为VM6的instance的ISO镜像<br />
</ol>
 <hr />
    <h2>Usage examples 使用样例</h2>
    example.sh
     <hr />
    <h2>Screenshot 截图</h2>
 <img src="https://raw.githubusercontent.com/asuhu/qemu-kvm/master/kvm.png"  alt="virsh version" />