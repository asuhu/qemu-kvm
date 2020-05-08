# qemu-kvm

<h2>KVM environment, support for Ceph rbd block storage, support for upgrading Qemu, support for upgrading libvirt<br /> </h2>
<h2> 一键安装KVM环境，支持Ceph rbd块存储，支持升级Qemu，支持升级libvirt<br /> </h2>
 <ol>
<li>需要服务器支持虚拟化技术Virtualization Technological</li>
<li>tuned-adm profile virtual-host   #Optimize for running KVM guests</li>
<li>--video virtio   #支持高分辨率https://libvirt.org/formatdomain.html#elementsVideo</li>
<li>--boot uefi,cdrom,hd,network,menu=on   #UEFI 启动（需要升级qemu-kvm）</li>
<li>--machine q35   #Standard PC (Q35 + ICH9, 2009) (alias of pc-q35-4.2)</li>
<li>--features kvm_hidden=on  #Allow the KVM hypervisor signature to be hidden from the guest</li>
</ol>

 <hr />

 <h2>创建虚拟机<br /></h2>
     <ol>
<li>创建CentOS6</li>
    bash -x centos6.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
<li>创建CentOS7</li>
    bash -x centos7.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2008R2</li>
    bash -x win2k8r2.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2012R2</li>
    bash -x win2k12r2.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
<li>创建Windows Server 2016</li>
    bash -x win2k16.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
    <li>创建Windows Server 2019</li>
    bash -x win2k19.sh $1&nbsp;$2&nbsp;$3&nbsp;$4&nbsp;&nbsp;&nbsp;&nbsp;(name Memory CpuCont  DiskSize)<br />
        <li>例子 bash -x centos7.sh 7 1024 4 40</li>
    </ol>
    
 <hr />

  <h2>彻底摧毁虚拟机</h2>
 <ol>
<li>bash -x delete.sh&nbsp;$1&nbsp;&nbsp;&nbsp;&nbsp;(delete.sh name)</li>
</ol>
    <h2>升级后的版本</h2>
 <img src="https://raw.githubusercontent.com/asuhu/qemu-kvm/master/kvm.png"  alt="virsh version" />