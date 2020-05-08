#!/bin/bash
cores=$(cat /proc/cpuinfo | grep 'model name'| wc -l)
cname=$( cat /proc/cpuinfo | grep 'model name' | uniq | awk -F : '{print $2}')
tram=$( free -m | awk '/Mem/ {print $2}' )
swap=$( free -m | awk '/Swap/ {print $2}' )
next() {
    printf "%-70s\n" "-" | sed 's/\s/-/g'
}
next
echo "Total amount of Mem  : $tram MB"
echo "Total amount of Swap : $swap MB"
echo "CPU model            : $cname"
echo "Number of cores      : $cores"
next

if [ $tram -le 1000 ];then
exit 1
fi

#dos2unix the_test.sh
yum -y install wget gcc gcc-c++ make cmake vim screen epel-release net-tools git deltarpm
next

echo 'will yum install ceph-devel'
sleep 1

#yum install make bison flex automake autoconf boost-devel fuse-devel gcc-c++ \
#libtool libuuid-devel libblkid-devel keyutils-libs-devel cryptopp-devel fcgi-devel \
#libcurl-devel expat-devel gperftools-devel libedit-devel libatomic_ops-devel snappy-devel \
#leveldb-devel libaio-devel xfsprogs-devel git libudev-devel gperftools redhat-lsb bzip2 ntp \
#iptables-services wget expect vim -y

cat > /etc/yum.repos.d/ceph.repo << "EOF"
[ceph]
name=Ceph packages for $basearch
baseurl=https://download.ceph.com/rpm-luminous/el7/$basearch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-luminous/el7/noarch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://download.ceph.com/rpm-luminous/el7/SRPMS
enabled=0
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc
EOF

#sudo yum install ceph-deploy librbd* -y
sudo yum install ceph-deploy librbd-devel librbd1 -y
###########################################################
echo -e "\033[31m upgrade the qemu ... \033[0m \n"
sleep 1
wget -c https://download.qemu.org/qemu-2.10.2.tar.bz2
yum -y install zlib-devel glib2-devel autoconf automake libtool
cd ~/
tar -jxvf qemu-2.10.2.tar.bz2
cd ~/qemu-2.10.2
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc  --localstatedir=/var --libexecdir=/usr/libexec --enable-rbd
make -j`cat /proc/cpuinfo | grep "model name" | wc -l` && make install

#如果qemu没安装成功，则退出
if [ ! -e '/usr/libexec/qemu-kvm' ]; then
exit 1
fi

mv /usr/libexec/qemu-kvm{,.orig}
ln -s /usr/bin/qemu-system-x86_64  /usr/libexec/qemu-kvm
#getconf               iptables               newns                    qemu-kvm             virt-p2v
#getconf               iptables               newns                    qemu-kvm.orig        virt-p2v
sleep 20

virsh version
qemu-img --help | grep rbd