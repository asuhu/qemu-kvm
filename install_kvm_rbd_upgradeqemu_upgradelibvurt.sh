#!/bin/bash
##dos2unix the_test.sh
#install qemu-kvm
#upgrade qemu
#upgrade libvirt

if  [ -z "$(grep ' 7\.' /etc/redhat-release)" ] ;then
echo "This script need CentOS 7"
fi

if  ! cat /etc/resolv.conf|grep nameserver ;then
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 114.114.114.114
EOF
fi

wip=$(curl -s --connect-timeout 25 ipinfo.io | head -n 2|grep ip | awk -F '"' '{print $4}')
if [ -z ${wip} ];then
wip=$(curl -4 -s --connect-timeout 25 https://api.ip.la)
elif  [ -z ${wip} ];then
wip=kvm3
fi

#kernel
grubby --update-kernel=ALL --remove-args="rhgb"

#
if [ ! -e '/usr/bin/wget' ]; then yum -y install wget ;fi


yum -y install wget gcc gcc-c++ make cmake vim screen epel-release net-tools git
yum clean all && yum makecache && yum repolist
yum check-update && yum -y update

#yum groupinstall "X Window System" "GNOME Desktop" -y
#rm /etc/systemd/system/default.target
#ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target

#cat >> /etc/security/limits.conf <<EOF
#* soft nproc 65535  
#* hard nproc 65535  
#* soft nofile 65535  
#* hard nofile 65535  
#EOF

#echo "ulimit -SH 65535" >> /etc/rc.d/rc.local
#chmod +x /etc/rc.d/rc.local
#sysctl -p

#openvswitch
#rpm -ivh https://repos.fedorapeople.org/openstack/EOL/openstack-juno/epel-7/openvswitch-2.3.1-2.el7.x86_64.rpm
#systemctl restart  openvswitch && systemctl enable openvswitch
#ovs-vsctl add-br br-lan
#ovs-vsctl add-br br-wan

#yum install make bison flex automake autoconf boost-devel fuse-devel gcc-c++ \
#libtool libuuid-devel libblkid-devel keyutils-libs-devel cryptopp-devel fcgi-devel \
#libcurl-devel expat-devel gperftools-devel libedit-devel libatomic_ops-devel snappy-devel \
#leveldb-devel libaio-devel xfsprogs-devel git libudev-devel gperftools redhat-lsb bzip2 ntp \
#iptables-services wget expect vim -y

spkvm=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ $spkvm -le 0 ];then
echo "not support Virtualization Technological, check please."
kill -9 $$
fi

sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
systemctl restart sshd

#
hostnamectl set-hostname ${wip}
systemctl disable postfix && systemctl stop postfix
systemctl stop firewalld && systemctl disable firewalld
systemctl stop NetworkManager && systemctl disable NetworkManager

#
sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config
setenforce 0

yum -y install numa*
systemctl enable numad && systemctl start numad
echo 1 > /proc/sys/kernel/numa_balancing
echo 0 > /sys/kernel/mm/ksm/merge_across_nodes
echo 1 > /sys/kernel/mm/ksm/run

yum -y install ntp
timedatectl set-timezone Asia/Shanghai
ntpdate -s us.ntp.org.cn
sed -i 's/server 0.centos.pool.ntp.org iburst/server us.ntp.org.cn/g' /etc/ntp.conf
systemctl enable ntpd.service && systemctl start ntpd.service
hwclock -w

yum -y install libvirt*
yum -y install virt-*
systemctl enable libvirtd && systemctl restart libvirtd
yum install libguestfs-tools virt-install -y

#qemu-kvm
#qemu-kvm-common
#Package virt-manager-common-1.4.3-3.el7.noarch already installed and latest version
#Package 1:virt-v2v-1.36.10-6.el7_5.2.x86_64 already installed and latest version
#Package virt-manager-1.4.3-3.el7.noarch already installed and latest version
#Package virt-install-1.4.3-3.el7.noarch already installed and latest version
#Package 1:virt-p2v-maker-1.36.10-6.el7_5.2.x86_64 already installed and latest version
#Package virt-what-1.18-4.el7.x86_64 already installed and latest version
#Package virt-p2v-1.36.10-1.el7.noarch already installed and latest version
#Package virt-viewer-5.0-10.el7.x86_64 already installed and latest version
#Package virt-top-1.0.8-24.el7.x86_64 already installed and latest version
#Package virt-who-0.21.7-1.el7_5.noarch already installed and latest version
#Package 1:virt-dib-1.36.10-6.el7_5.2.x86_64 already installed and latest version

#tuned-adm list
#virtual-host                - Optimize for running KVM guests
tuned-adm profile virtual-host

mkdir -p /data/{iso,image,instance}

yum -y install  MySQL-python  wget bc lrzsz iftop xmlstarlet csh gcc gcc-c++ vim wget dos2unix
echo "alias vi='vim'"    >> /etc/profile

echo -e "\033[31m "kvm environment install done" \033[0m \n"
sleep 5
#######################################
read -p "Will you upgrade qemu (y or n): " upgrade_qemu
    [ -z "${upgrade_qemu}" ] && upgrade_qemu=n
if [ ${upgrade_qemu} = "y" ] ;then
##########Yum Ceph-devel
yum -y install wget gcc gcc-c++ make cmake vim screen epel-release net-tools git deltarpm
yum -y install flex bison
#make[1]: flex: Command not foundmake[1]: bison: Command not found

echo -e "\033[31m "will yum install ceph-devel" \033[0m \n"
sleep 5
cat > /etc/yum.repos.d/ceph.repo << "EOF"
[ceph]
name=Ceph packages for $basearch
baseurl=https://download.ceph.com/rpm-mimic/el7/$basearch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-mimic/el7/noarch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://download.ceph.com/rpm-mimic/el7/SRPMS
enabled=0
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc
EOF

#sudo yum install ceph-deploy librbd* -y
sudo yum install ceph-deploy librbd-devel librbd1 -y

if [ ! -f '/usr/bin/ceph-deploy' ];then
echo "Install ceph-devel error"
kill -9 $$
fi
#Upgrade qemu and support ceph storage
echo -e "\033[31m will upgrade the qemu ... \033[0m \n"
yum -y install zlib-devel glib2-devel autoconf automake libtool
yum -y install pixman pixman-devel          #ERROR: pixman >= 0.21.8 not present.Please install the pixman devel package.
qemuversion=qemu-3.1.1
cd ~/
if wget -4 -q -t 5 https://download.qemu.org/${qemuversion}.tar.bz2   #https://download.qemu.org/qemu-2.12.1.tar.xz
then
echo "download qemu success"
else
wget -4 -q http://arv.asuhu.com/ftp/so/${qemuversion}.tar.bz2
fi

tar -jxf ${qemuversion}.tar.bz2 && rm -rf ${qemuversion}.tar.bz2
cd ~/${qemuversion}
 yum -y install libseccomp libseccomp-devel
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --localstatedir=/var --libexecdir=/usr/libexec --enable-rbd --enable-seccomp
make -j`cat /proc/cpuinfo | grep "model name" | wc -l` && make install

#Exit if qemu is not installed successfully
if [ ! -e '/usr/bin/qemu-system-x86_64' ]; then
echo "Install ${qemuversion} error"
kill -9 $$
fi

mv -f /usr/libexec/qemu-kvm{,.orig}
ln -s /usr/bin/qemu-system-x86_64  /usr/libexec/qemu-kvm
#getconf               iptables               newns                    qemu-kvm             virt-p2v
#getconf               iptables               newns                    qemu-kvm.orig        virt-p2v

sleep 1
virsh version
qemu-img --help | grep rbd
sleep 1
 else
echo "Not upgraded qemu"
fi
############libvirt
read -p "Will you upgrade libvirt (y or n): " upgrade_libvirt
    [ -z "${upgrade_libvirt}" ] && upgrade_libvirt=n
if [[ ${upgrade_libvirt} = "y" || ${upgrade_libvirt} = "Y" ]] ;then

for i in `find /etc/libvirt -name "*.conf" | xargs  ls`;do cp $i  ${i}.`date +"%Y%m%d_%H%M%S"`;done
#https://libvirt.org/sources/libvirt-5.7.0.tar.xz
LibvirtVersion=libvirt-5.7.0
cd ~
wget https://libvirt.org/sources/${LibvirtVersion}.tar.xz
tar -Jxvf ${LibvirtVersion}.tar.xz && rm -rf ${LibvirtVersion}.tar.xz
cd ${LibvirtVersion}
yum -y install libxml2-devel gnutls-devel device-mapper-devel python-devel libnl-devel
yum -y install libpciaccess libpciaccess-devel cmake
yum -y install libxslt yajl-devel yajl
yum -y install netcf netcf-devel libnl3-devel
./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --libdir=/usr/lib64 --with-netcf
#./autogen.sh --system  #保持对操作系统发型版中安装可执行程序和共享库的目录的一致性
sudo make -j`cat /proc/cpuinfo | grep "model name" | wc -l` && sudo make install

systemctl daemon-reload
service libvirtd restart
else
  echo "not upgrade libvirt"
fi

virsh version
#/etc/libvirt
#/etc/libvirt  libvirt.conf  libvirtd.conf  lxc.conf  qemu  qemu.conf #https://wiki.archlinux.org/index.php/Libvirt_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)
#/var/lib/libvirt