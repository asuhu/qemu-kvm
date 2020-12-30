#!/vin/bash
a=$(cat /proc/cpuinfo | grep 'model name'| wc -l)
yum install gcc perl-ExtUtils-MakeMaker wget vim git ncurses-devel -y
cd /usr/src
git clone https://github.com/vim/vim.git
cd vim/src
make -j$a
make install
vim --version


yum install curl-devel expat-devel gettext-devel openssl-devel zlib-devel -y
yum -y install openssl openssl-devel
mkdir  /usr/src/openssl
curl -Lk https://www.openssl.org/source/openssl-1.0.2-latest.tar.gz|gunzip |tar x -C /usr/src/openssl
cd /usr/src/openssl/openssl-1.0.??
./config --prefix=/usr shared zlib
make -j $(awk '/processor/{i++}END{print i}' /proc/cpuinfo) && make install
openssl version


yum groupinstall "Development tools" -y
yum -y install glib2-devel
wget https://download.qemu.org/qemu-2.10.1.tar.xz
tar -Jxvf qemu-2.10.1.tar.xz
cd qemu-2.10.1
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc  --localstatedir=/var --libexecdir=/usr/libexec --enable-rbd
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc  --localstatedir=/var --libexecdir=/usr/libexec
make -j $(awk '/processor/{i++}END{print i}' /proc/cpuinfo)
make install
mv /usr/libexec/qemu-kvm{,.orig}  #全新安装的不需要这部，升级现有的需要
ln -s /usr/bin/qemu-system-x86_64  /usr/libexec/qemu-kvm


wget https://libvirt.org/sources/libvirt-4.8.0.tar.xz
tar -Jxvf libvirt-4.8.0.tar.xz
cd libvirt-4.8.0
yum -y install libxml2-devel gnutls-devel device-mapper-devel python-devel libnl-devel
yum -y install libpciaccess libpciaccess-devel cmake
yum -y install libxslt yajl-devel yajl
./autogen.sh --system  ###个人推荐这个方法##保持对操作系统发型版中安装可执行程序和共享库的目录的一致性
#Running configure with --prefix=/usr --localstatedir=/var --sysconfdir=/etc --libdir=/usr/lib64 
sudo make && sudo make install

#git clone git://github.com/lloyd/yajl
#cd yajl
#./configure
#make -j`cat /proc/cpuinfo | grep "model name" | wc -l` && make install



#/usr/lib64/libvirt.so
#/usr/lib64/libvirt-qemu.so


#libvirtd单元
cat > /usr/lib/systemd/system/libvirtd.service << "EOF"
# NB we don't use socket activation. When libvirtd starts it will
# spawn any virtual machines registered for autostart. We want this
# to occur on every boot, regardless of whether any client connects
# to a socket. Thus socket activation doesn't have any benefit

[Unit]
Description=Virtualization daemon
Requires=virtlogd.socket
Before=libvirt-guests.service
After=network.target
After=dbus.service
After=iscsid.service
After=apparmor.service
After=local-fs.target
After=remote-fs.target
Documentation=man:libvirtd(8)
Documentation=http://libvirt.org

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/libvirtd
ExecStart=/usr/sbin/libvirtd $LIBVIRTD_ARGS
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
# At least 1 FD per guest, often 2 (eg qemu monitor + qemu agent).
# eg if we want to support 4096 guests, we'll typically need 8192 FDs
# If changing this, also consider virtlogd.service & virtlockd.service
# limits which are also related to number of guests
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
Also=virtlockd.socket
Also=virtlogd.socket
EOF
