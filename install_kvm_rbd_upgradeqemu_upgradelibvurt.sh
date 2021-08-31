#!/bin/bash
#dos2unix install_kvm_rbd_upgradeqemu_upgradelibvurt.sh
############################
#Email  860116511@qq.com
#Date 20210828
#1 yum install qemu-kvm libvirt
#2 Source code compilation upgrade qemu4.2.1 , CentOS 7 is no longer a supported build platform qemu 6.1
#3 Source code compilation upgrade libvirt6.2.0
#4 configure KVM nested
#5 configure UEFI
#6 configure KVM_PCI_Passthrough
############################
#yum install centos-release-qemu-ev
#Running hypervisor: QEMU 2.12.1
############################
#31m red
#32m blue
############################
if  [ -z "$(grep ' 7\.' /etc/redhat-release)" ] ;then
	kill -9 $$
	echo -e "\033[32m "This script need CentOS 7" \033[0m \n"
fi
#dns
if  ! cat /etc/resolv.conf|grep nameserver ;then
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 114.114.114.114
EOF
fi
#hostname
wip=$(curl -s --connect-timeout 25 ipinfo.io | head -n 2|grep ip | awk -F '"' '{print $4}')
if [ -z ${wip} ];then
wip=kvm.local
fi
hostnamectl set-hostname ${wip}
#kernel
grubby --update-kernel=ALL --remove-args="rhgb"
#
sed -i 's@^#UseDNS yes@UseDNS no@' /etc/ssh/sshd_config
sed -i 's@^GSSAPIAuthentication yes@GSSAPIAuthentication no@' /etc/ssh/sshd_config
setenforce 0
sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config
#
yum -y remove mariadb mysql
yum -y install epel-release
if [ ! -e '/usr/bin/wget' ]; then yum -y install wget ;fi
wget -4 -O /etc/yum.repos.d/CentOS-Base.repo http://qnvideo.henan100.net/Centos-7.repo
sed -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!//download\.fedoraproject\.org/pub!//mirrors.tuna.tsinghua.edu.cn!g' \
    -e 's!http://mirrors\.tuna!https://mirrors.tuna!g' \
    -i /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-testing.repo
yum -y install rsync wget gcc screen net-tools dnf unzip vim htop
#ntpdate
yum -y install ntpdate
if [ -e "$(which ntpdate)" ]; then
  ntpdate -u pool.ntp.org
  [ ! -e "/var/spool/cron/root" -o -z "$(grep 'ntpdate' /var/spool/cron/root)" ] && { echo "*/20 * * * * $(which ntpdate) -u pool.ntp.org > /dev/null 2>&1" >> /var/spool/cron/root;chmod 600 /var/spool/cron/root; }
fi
yum -y install ntp
timedatectl set-timezone Asia/Shanghai
ntpdate -s us.ntp.org.cn
sed -i 's/server 0.centos.pool.ntp.org iburst/server us.ntp.org.cn/g' /etc/ntp.conf
systemctl enable ntpd.service && systemctl start ntpd.service
hwclock -w
#
yum -y install wget gcc gcc-c++ make cmake vim screen epel-release net-tools git
yum clean all && yum makecache && yum repolist
yum check-update && yum -y update

#yum groupinstall "X Window System" "GNOME Desktop" -y
#rm /etc/systemd/system/default.target
#ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target

#openvswitch
#rpm -ivh https://repos.fedorapeople.org/openstack/EOL/openstack-juno/epel-7/openvswitch-2.3.1-2.el7.x86_64.rpm
#systemctl restart  openvswitch && systemctl enable openvswitch
#ovs-vsctl add-br br-lan
#ovs-vsctl add-br br-wan
#
spkvm=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ $spkvm -le 0 ];then
	echo -e "\033[32m "No support Virtualization Technological, check please." \033[0m \n"
kill -9 $$
fi
#
#SSH
sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
systemctl restart sshd
#
sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config
setenforce 0
#
systemctl disable postfix && systemctl stop postfix
systemctl stop firewalld && systemctl disable firewalld
systemctl stop NetworkManager && systemctl disable NetworkManager
#
#numad numactl numactl-devel numactl-libs
yum -y install numa*
systemctl enable numad && systemctl start numad
echo 1 > /proc/sys/kernel/numa_balancing
echo 0 > /sys/kernel/mm/ksm/merge_across_nodes
echo 1 > /sys/kernel/mm/ksm/run
#
#yum -y install virt-manager virt-manager-common  #图形管理工具
yum -y install lsof unzip
yum -y install qemu-kvm qemu-kvm-tools qemu-kvm-common virt-who virt-viewer virt-v2v virt-top virt-install virt-dib  #This step will install rpcbind
yum -y install libvirt libvirt-admin libvirt-bash-completion libvirt-cim libvirt-client libvirt-daemon \
libvirt-daemon-config-network libvirt-daemon-config-nwfilter libvirt-daemon-driver-interface libvirt-daemon-driver-lxc \
libvirt-daemon-driver-network libvirt-daemon-driver-nodedev libvirt-daemon-driver-nwfilter libvirt-daemon-driver-qemu \
libvirt-daemon-driver-secret libvirt-daemon-driver-storage libvirt-daemon-driver-storage-core libvirt-daemon-driver-storage-disk \
libvirt-daemon-driver-storage-gluster libvirt-daemon-driver-storage-iscsi libvirt-daemon-driver-storage-logical libvirt-daemon-driver-storage-mpath \
libvirt-daemon-driver-storage-rbd libvirt-daemon-driver-storage-scsi libvirt-daemon-kvm libvirt-daemon-lxc \
libvirt-dbus libvirt-devel libvirt-docs libvirt-libs libvirt-lock-sanlock libvirt-login-shell libvirt-nss libvirt-python libvirt-snmp
systemctl enable libvirtd && systemctl restart libvirtd
#
#libguestfs is a set of tools for accessing and modifying virtual machine (VM) disk images
yum install libguestfs-tools -y
#
#Danger needs to be disabled rpcbind 
systemctl stop rpcbind && systemctl mask rpcbind  #yum -y remove rpcbind
#136.243.4.154 | 2019-09-17 06:34:07 | 100000 4 111/udp; 100000 3 111/udp; 100000 2 111/udp; 100000 4 111/udp; 100000 3 111/udp; 100000 2 111/udp;
#The Portmapper service runs on port 111 tcp/udp.
#
#tuned-adm list
#virtual-host  - Optimize for running KVM guests
tuned-adm profile virtual-host
#
mkdir -p /data/{iso,image,instance}
yum -y install  MySQL-python  wget bc lrzsz iftop xmlstarlet csh gcc gcc-c++ vim wget dos2unix
echo "alias vi='vim'"    >> /etc/profile
#
echo -e "\033[32m "KVM environment installation is complete" \033[0m \n"
sleep 2
####################################################################
read -p "Will you upgrade qemu (y or n): " upgrade_qemu
    [ -z "${upgrade_qemu}" ] && upgrade_qemu=n
if [ ${upgrade_qemu} = "y" ] ;then
##########CentOS7 Yum Install Ceph-devel Nautilus(鹦鹉螺)
yum -y install wget gcc gcc-c++ make cmake vim screen epel-release net-tools git deltarpm
yum -y install flex bison    #make[1]: flex: Command not foundmake[1]: bison: Command not found

echo -e "\033[32m "will yum install ceph-devel v14 Nautilus" \033[0m \n"
sleep 5
if ping -c 10 216.58.200.4 >/dev/null;then
cat > /etc/yum.repos.d/ceph.repo << "EOF"
[Ceph]
name=Ceph packages for $basearch
baseurl=http://download.ceph.com/rpm-nautilus/el7/$basearch
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://download.ceph.com/rpm-nautilus/el7/noarch
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=http://download.ceph.com/rpm-nautilus/el7/SRPMS
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
EOF
else
cat > /etc/yum.repos.d/ceph.repo << "EOF"
[Ceph]
name=Ceph packages for $basearch
baseurl=https://mirrors.aliyun.com/ceph/rpm-nautilus/el7/$basearch
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc

[Ceph-noarch]
name=Ceph noarch packages
baseurl=https://mirrors.aliyun.com/ceph/rpm-nautilus/el7/noarch
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://mirrors.aliyun.com/ceph/rpm-nautilus/el7/SRPMS
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
EOF
fi
#rpm -ivh https://download.ceph.com/rpm-nautilus/el7/noarch/ceph-release-1-1.el7.noarch.rpm
#ceph-deploy是ceph官方提供的部署工具
#librbd1 RADOS block device client library https://packages.debian.org/sid/librbd1
#librbd-dev RADOS block device client library (development files) https://packages.debian.org/zh-cn/sid/librbd-dev
#
yum -y install ceph-deploy librbd-devel librbd1
#
if [ ! -f '/usr/bin/ceph-deploy' ];then
	echo "Install ceph-devel error"
kill -9 $$
fi
#
#disable Ceph repo
if ! which yum-config-manager;then yum -y install yum-utils;fi
sudo yum-config-manager --disable Ceph Ceph-noarch ceph-source
#
#yum -y install epel-release
yum install -y python36 python36-setuptools python36-devel
#warning: Python 2 support is deprecated
#warning: Python 3 will be required for building future versions of QEMU 4.2.0

#Upgrade qemu and support ceph storage
echo -e "\033[32m Upgrade qemu and support ceph storage ... \033[0m \n"
sleep 1
yum -y install zlib-devel glib2-devel autoconf automake libtool
yum -y install pixman pixman-devel              #ERROR: pixman >= 0.21.8 not present.Please install the pixman devel package.
qemuversion=qemu-4.2.1
cd ~
	if wget -4 -q -t 5 http://file.asuhu.com/kvm/${qemuversion}.tar.xz;then
		echo "download qemu success"
		else
	wget -4 -q https://download.qemu.org/${qemuversion}.tar.xz
	fi
#
yum -y install libseccomp libseccomp-devel
yum -y install libaio-devel                   #异步IO
yum -y install bzip2-devel                   #--enable-bzip2
yum -y install snappy-devel                #snappy support 
yum -y install libcurl-devel 
yum -y install gtk3-devel                    #--enable-gtk
yum -y install  nettle-devel  libxml2-devel
yum  -y install ninja-build
yum -y install spice-server spice-protocol spice-server-devel  #Install sparse binary  --enable-sparse   #Sparse is a semantic checker for C programs; it can be used to find a number of potential problems with kernel code
tar -xf ${qemuversion}.tar.xz && rm -rf ${qemuversion}.tar.xz
cd ~/${qemuversion}
 ./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --localstatedir=/var --libexecdir=/usr/libexec \
--enable-rbd --enable-seccomp --enable-linux-aio --enable-bzip2 --enable-tools  --enable-curl  --enable-snappy \
--enable-gtk --enable-spice  --enable-libxml2
#
make -j`cat /proc/cpuinfo | grep "model name" | wc -l` && make install

#Exit if qemu is not installed successfully
if [ ! -e '/usr/bin/qemu-system-x86_64' ]; then
	echo -e "\033[31m Install ${qemuversion} Error... \033[0m \n"
kill -9 $$
fi

mv -f /usr/libexec/qemu-kvm{,.orig}
ln -s /usr/bin/qemu-system-x86_64  /usr/libexec/qemu-kvm
#qemu-kvm	qemu-kvm.orig	virt-p2v

sleep 2
virsh version
qemu-img --help | grep rbd
 else
	echo -e "\033[31m "No upgraded qemu" \033[0m \n"
fi
######################libvirt##########################
read -p "Will you upgrade libvirt (y or n): " upgrade_libvirt
    [ -z "${upgrade_libvirt}" ] && upgrade_libvirt=n
if [[ ${upgrade_libvirt} = "y" || ${upgrade_libvirt} = "Y" ]] ;then
#
	for i in `find /etc/libvirt -name "*.conf" | xargs  ls`;do cp $i  ${i}.`date +"%Y%m%d_%H%M%S"`;done
	#https://libvirt.org/sources/libvirt-6.2.0.tar.xz
	#https://libvirt.org/compiling.html#compiling  #Future installation
	LibvirtVersion=libvirt-6.6.0
	cd ~
		if wget -4 -q -t 5 http://file.asuhu.com/kvm/${LibvirtVersion}.tar.xz;then
			echo "download libvirt success"
			else
			wget https://libvirt.org/sources/${LibvirtVersion}.tar.xz
		fi
	yum -y install libxml2-devel gnutls-devel device-mapper-devel python-devel libnl-devel
	yum -y install libpciaccess libpciaccess-devel cmake
	yum -y install libxslt yajl-devel yajl
	yum -y install netcf netcf-devel libnl3-devel
	yum -y install python-docutils           #configure: error: "rst2html5/rst2html is required to build libvirt
	yum -y install libtirpc-devel
	tar -xf ${LibvirtVersion}.tar.xz && rm -rf ${LibvirtVersion}.tar.xz
	cd ${LibvirtVersion}
	mkdir build && cd build
	../configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --libdir=/usr/lib64 --with-netcf
	sudo make -j`cat /proc/cpuinfo | grep "model name" | wc -l` && sudo make install
	#Exit if Libvirt is not installed successfully
		if [ $? -ne 0 ];then
			echo -e "\033[31m ${LibvirtVersion} Install Error ... \033[0m \n"
		kill -9 $$
		fi
	#./autogen.sh --system  #保持对操作系统发型版中安装可执行程序和共享库的目录的一致性
	#
	systemctl daemon-reload && systemctl enable libvirtd
	service libvirtd restart
else
	echo -e "\033[31m "No upgrade libvirt" \033[0m \n"
fi
sleep 1
virsh version
######################kvm_nested##########################
read -p "Will you config KVM nested (y or n): " upgrade_nested
    [ -z "${upgrade_nested}" ] && upgrade_nested=n && upgrade_nested=N
if [[ ${upgrade_nested} = "y" || ${upgrade_nested} = "Y" ]] ;then
#
	kvm_nested=`lscpu |grep "Model name"|grep Intel|awk '{for (i=3;i<NF;i++){printf $i"  "} print $NF}'`
		 if [ -z "${kvm_nested}" ];then
		echo -e "\033[32m "Configure AMD nested" \033[0m \n"
				if [ `cat /sys/module/kvm_amd/parameters/nested` == 0 ];then
						sudo sh -c "echo 'options kvm-amd nested=1' >> /etc/modprobe.d/dist.conf"
						else
						echo "Already configured nested"
				fi
	            else
		echo -e "\033[32m "Configure Intel nested" \033[0m \n"
				if [ `cat /sys/module/kvm_intel/parameters/nested` == N ];then
						sudo sh -c "echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf"
						else
						echo "Already configured nested"
				fi
		fi
else
	echo -e "\033[31m "No upgrade_nested" \033[0m \n"
fi
sleep 1
######################kvm_uefi##########################
read -p "Will you config UEFI (y or n): " upgrade_uefi
    [ -z "${upgrade_uefi}" ] && upgrade_uefi = n
if [[ ${upgrade_uefi} = "y" || ${upgrade_uefi} = "Y" ]] ;then
#
		upgrade_uefi=`uname -r | grep x86_64`
		 if [ -z "${upgrade_uefi}" ];then
			echo -e "\033[32m "Configure ARM_64 UEFI" \033[0m \n"
			rpm -ivh http://qnvideo.henan100.net/edk2.git-aarch64.noarch.rpm
cat >> /etc/libvirt/qemu.conf <<'EOF'
nvram = [
"/usr/share/edk2.git/aarch64/QEMU_EFI-pflash.raw:/usr/share/edk2.git/aarch64/vars-template-pflash.raw"
]
EOF
systemctl restart libvirtd
#
	            else
			echo -e "\033[32m "Configure x86_64 UEFI" \033[0m \n"
			rpm -ivh http://qnvideo.henan100.net/edk2.git-ovmf-x64.noarch.rpm
\cp -f /usr/share/qemu/firmware/81-ovmf-x64-git-pure-efi.json /usr/share/qemu/firmware/31-ovmf-x64-git-pure-efi.jsonsystemctl restart libvirtd
		fi
else
	echo -e "\033[31m "No upgrade_uefi" \033[0m \n"
fi
sleep 1
######################KVM_PCI_Passthrough##########################
read -p "Will you config KVM PCI Passthrough Kernel (y or n): " KVM_PCI_Passthrough
    [ -z "${KVM_PCI_Passthrough}" ] && KVM_PCI_Passthrough= n
if [[ ${KVM_PCI_Passthrough} = "y" || ${KVM_PCI_Passthrough} = "Y" ]] ;then
#
	kvm_nested=`lscpu |grep "Model name"|grep Intel|awk '{for (i=3;i<NF;i++){printf $i"  "} print $NF}'`
		 if [ -z "${kvm_nested}" ];then
		echo -e "\033[32m "Configure AMD KVM_PCI_Passthrough" \033[0m \n"
			grubby --update-kernel=ALL --args="amd_iommu=on" --args=" modprobe.blacklist=snd_hda_intel,amd76x_edac,vga16fb,nouveau,rivafb,nvidiafb,rivatv,amdgpu,radeon"
			echo -e "\033[32m "Display all kernel information of the system" \033[0m \n"
			grubby --info=ALL
			echo -e "\033[31m "Now AMD KVM PCI Passthrough Kernel configuration is complete , You need config vfio to VM instance" \033[0m \n"
	            else
		echo -e "\033[32m "Configure Intel KVM_PCI_Passthrough" \033[0m \n"
			grubby --update-kernel=ALL --args="intel_iommu=on" --args=" modprobe.blacklist=snd_hda_intel,amd76x_edac,vga16fb,nouveau,rivafb,nvidiafb,rivatv,amdgpu,radeon"
			echo -e "\033[32m "Display all kernel information of the system" \033[0m \n"
			grubby --info=ALL
			echo -e "\033[31m "Now Intel KVM PCI Passthrough Kernel configuration is complete , You need config vfio to VM instance" \033[0m \n"
		fi
#
else
	echo -e "\033[31m "No configuration KVM PCI Passthrough Kernel" \033[0m \n"
fi
#
sleep 1
#Configuration Optimization
sed  -i 's@^#listen_tcp = 1@listen_tcp = 1@' /etc/libvirt/libvirtd.conf
sed  -i 's@^#listen_tls = 0@listen_tls = 0@' /etc/libvirt/libvirtd.conf
sed  -i 's@^#tcp_port = "16509"@tcp_port = "16509"@' /etc/libvirt/libvirtd.conf
sed  -i 's@^#auth_tcp = "sasl"@auth_tcp = "none"@' /etc/libvirt/libvirtd.conf

sed -i 's@^#user = "root"@user = "root"@' /etc/libvirt/qemu.conf 
sed -i 's@^#group = "root"@group = "root"@' /etc/libvirt/qemu.conf
sed -i 's@^#security_driver = "selinux"@security_driver = "none"@' /etc/libvirt/qemu.conf 
#
virsh version
	echo -e "\033[32m "You need config bridge , virsh iface-bridge eth0 br0" \033[0m \n"
	echo -e "\033[32m "You need config switch lacp" \033[0m \n"
#/etc/libvirt  libvirt.conf  libvirtd.conf  lxc.conf  qemu  qemu.conf #https://wiki.archlinux.org/index.php/Libvirt_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)
#/var/lib/libvirt