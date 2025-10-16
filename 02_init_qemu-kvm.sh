#!/bin/bash
set -e
set -o pipefail

echo "==================== [系统检测与初始化] ===================="
OS_ID=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    echo "检测到系统: $PRETTY_NAME"
else
    echo "无法检测操作系统版本，请确认系统兼容 Ubuntu / RockyLinux"
    exit 1
fi

# 通用依赖初始化
echo "[1/8] 更新系统包..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    apt update -y
elif [[ "$OS_ID" =~ (rocky|rhel|centos) ]]; then
    dnf makecache -y || yum makecache -y
else
    echo "暂不支持此系统: $OS_ID"
    exit 1
fi
sleep 1


echo "[2/8] 安装 KVM 及相关组件..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager virt-v2v
    apt install -y libosinfo-bin ovmf libguestfs-tools
elif [[ "$OS_ID" =~ (rocky|rhel|centos) ]]; then
    dnf install -y @virt virt-install libvirt libvirt-daemon-kvm virt-manager virt-viewer virt-top virt-v2v
    dnf install -y qemu-kvm qemu-img qemu-block-rbd libvirt-client bridge-utils libguestfs-tools ovmf
fi
sleep 1


echo "[3/8] 开始优化 libvirt 配置..."
CONF_LIBVIRTD="/etc/libvirt/libvirtd.conf"
#开启TCP监听
sed -i 's/^#\?\s*listen_tcp\s*=.*/listen_tcp = 1/' "$CONF_LIBVIRTD"
#禁用TLS
sed -i 's/^#\?\s*listen_tls\s*=.*/listen_tls = 0/' "$CONF_LIBVIRTD"
sed -i 's/^#\?\s*tcp_port\s*=.*/tcp_port = "16509"/' "$CONF_LIBVIRTD"
#免去账户密码验证，适合内网服务器
#virsh -c "qemu+tcp://<服务器IP>:16509/system"
sed -i 's/^#\?\s*auth_tcp\s*=.*/auth_tcp = "none"/' "$CONF_LIBVIRTD"
sed -i 's@^#\?\s*log_outputs\s*=.*@log_outputs="1:file:/var/log/libvirt/libvirtd.log"@' "$CONF_LIBVIRTD"
sleep 1


echo "[4/8] 开始优化 qemu 权限和安全..."
CONF_QEMU="/etc/libvirt/qemu.conf"
sed -i 's/^#\?\s*user\s*=.*/user = "qemu"/' "$CONF_QEMU"
sed -i 's/^#\?\s*group\s*=.*/group = "qemu"/' "$CONF_QEMU"
sed -i 's/^#\?\s*security_driver\s*=.*/security_driver = "none"/' "$CONF_QEMU"
#security_driver 默认值通常是 selinux 或 apparmor，用于在宿主机层面给每个虚拟机进程加安全沙箱。


LIBVIRTD_SERVICE="/etc/systemd/system/libvirtd.service.d/tcp.conf"
mkdir -p "$(dirname "$LIBVIRTD_SERVICE")"
cat > "$LIBVIRTD_SERVICE" <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/libvirtd --listen
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl restart libvirtd

echo "[5/8] 启动并检查 libvirtd 服务..."
systemctl enable --now libvirtd
systemctl status libvirtd --no-pager
sleep 1


#######################################
# QEMU 源码编译与 RBD 支持
#######################################
echo
echo "==================== [QEMU 编译与 RBD 支持] ===================="

QEMU_VERSION="8.2.10"
QEMU_PKGNAME="qemu-kvm-suhu"
PREFIX="/usr/local/qemu"
BUILD_DIR="$HOME/qemu-${QEMU_VERSION}/build"

read -p "是否启用 RBD (Ceph 块设备) 支持？[Y/n]: " enable_rbd
if [[ "$enable_rbd" =~ ^[Nn]$ ]]; then
    echo "已禁用 RBD 支持"
else
    echo "启用 RBD 支持并开始编译 QEMU"
fi

echo "[1/8] 安装编译依赖..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    sudo apt update && sudo apt install -y \
      git build-essential libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev \
      ninja-build meson python3-pip libnfs-dev libiscsi-dev libaio-dev libbluetooth-dev \
      libcap-ng-dev libcurl4-openssl-dev libssh-dev libvte-2.91-dev libgtk-3-dev \
      libspice-server-dev libusb-1.0-0-dev libusbredirparser-dev libseccomp-dev \
      liblzo2-dev librbd-dev libibverbs-dev libnuma-dev libsnappy-dev \
      libbz2-dev libzstd-dev libpam0g-dev libsasl2-dev libselinux1-dev \
      libepoxy-dev libpulse-dev libjack-jackd2-dev libasound2-dev \
      libdrm-dev libgbm-dev libudev-dev libvhost-user-dev \
      librdmacm-dev libibumad-dev libmultipath-dev checkinstall
elif [[ "$OS_ID" =~ (rocky|rhel|centos) ]]; then
    dnf install -y epel-release
    dnf install -y git gcc gcc-c++ make meson ninja-build python3-pip \
      glib2-devel pixman-devel zlib-devel libaio-devel libusb-devel \
      libusbredir-devel libcurl-devel libssh-devel libcap-ng-devel libnfs-devel \
      librbd-devel librados-devel rdma-core-devel numactl-devel libiscsi-devel \
      bzip2-devel snappy-devel zstd-devel libdrm-devel spice-server-devel gtk3-devel \
      libusbx-devel libvte3-devel libepoxy-devel alsa-lib-devel jack-audio-connection-kit-devel \
      checkinstall
fi


echo "[2/8] 下载 QEMU 源码..."
cd ~
wget -c https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz
tar -Jxvf qemu-${QEMU_VERSION}.tar.xz

echo "[3/8] 配置构建目录..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[4/8] 运行 configure..."
../configure \
  --prefix=${PREFIX} \
  --libdir=lib \
  --target-list=x86_64-softmmu \
  --enable-kvm \
  --enable-linux-aio \
  --enable-io-uring \
  --enable-rbd \
  --enable-virtfs \
  --enable-vhost-user \
  --enable-vnc \
  --enable-spice \
  --enable-libusb \
  --enable-usb-redir \
  --enable-lzo \
  --enable-seccomp \
  --enable-curl \
  --enable-numa \
  --enable-fdt \
  --enable-tools \
  --enable-coroutine-pool \
  --enable-snappy \
  --enable-bzip2 \
  --enable-zstd \
  --enable-rdma \
  --enable-multipath \
  --buildtype=release

echo "[5/8] 开始编译 QEMU..."
make -j$(nproc)

echo "[6/8] 使用 checkinstall 打包..."
sudo checkinstall --pkgname=${QEMU_PKGNAME} --pkgversion=${QEMU_VERSION} \
  --backup=no --deldoc=yes --fstrans=no --default <<EOF
y
EOF

echo "[7/8] 安装打好的 DEB/RPM 包..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    sudo dpkg -i ${BUILD_DIR}/${QEMU_PKGNAME}_${QEMU_VERSION}-1_amd64.deb
elif [[ "$OS_ID" =~ (rocky|rhel|centos) ]]; then
    sudo rpm -ivh ${BUILD_DIR}/${QEMU_PKGNAME}-${QEMU_VERSION}-1.x86_64.rpm || true
fi

echo "[8/8] 创建软链接 (可选)..."
sudo ln -sf ${PREFIX}/bin/qemu-system-x86_64 /usr/bin/qemu-system-x86_64
sudo ln -sf ${PREFIX}/bin/qemu-img /usr/bin/qemu-img

echo "安装完成！验证版本："
qemu-system-x86_64 --version


#######################################
# 嵌套虚拟化与 IOMMU 直通
#######################################
echo
echo "==================== [嵌套虚拟化与显卡直通配置] ===================="

CPU_MODEL=$(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)
echo "当前 CPU: $CPU_MODEL"

if grep -q vmx /proc/cpuinfo; then
    CPU_VENDOR="intel"
elif grep -q svm /proc/cpuinfo; then
    CPU_VENDOR="amd"
else
    echo "无法检测虚拟化支持，请检查 BIOS 设置"
    exit 1
fi

echo "检测到 CPU 类型：$CPU_VENDOR"

if [[ "$CPU_VENDOR" == "intel" ]]; then
    echo "启用 Intel 嵌套虚拟化..."
    sudo modprobe -r kvm_intel || true
    sudo modprobe kvm_intel nested=1
    echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm-nested.conf
elif [[ "$CPU_VENDOR" == "amd" ]]; then
    echo "启用 AMD 嵌套虚拟化..."
    sudo modprobe -r kvm_amd || true
    sudo modprobe kvm_amd nested=1
    echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm-nested.conf
fi

echo
echo "启用 IOMMU 支持..."
GRUB_FILE="/etc/default/grub"
if [[ "$CPU_VENDOR" == "intel" ]]; then
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt"/' $GRUB_FILE
else
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt"/' $GRUB_FILE
fi
sudo update-grub || sudo grub2-mkconfig -o /boot/grub2/grub.cfg

echo
echo "配置 VFIO 模块..."
sudo tee /etc/modules-load.d/vfio.conf > /dev/null <<EOF
vfio
vfio_iommu_type1
vfio_pci
EOF

sudo modprobe vfio
sudo modprobe vfio_iommu_type1
sudo modprobe vfio_pci
lsmod | grep vfio || echo "VFIO 模块未正确加载"

echo
echo "屏蔽主机 NVIDIA 驱动..."
cat <<EOF | sudo tee /etc/modprobe.d/blacklist-nvidia.conf
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist rivafb
EOF

echo
echo "更新 initramfs..."
sudo update-initramfs -u || sudo dracut -f

echo
echo "配置完成 请执行以下命令重启系统生效"
echo "sudo reboot"