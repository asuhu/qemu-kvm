#!/bin/bash
# =========================================
# Ubuntu、Debian安装和升级KVM
# 作者：asuhu
# =========================================

set -e
set -o pipefail

echo "==================== [系统检测与初始化] ===================="
OS_ID=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    echo "检测到系统: $PRETTY_NAME"
else
    echo "无法检测操作系统版本，请确认系统兼容 Ubuntu / Debian"
    exit 1
fi

# 通用依赖初始化
echo "[1/8] 更新系统包..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    apt update -y
else
    echo "暂不支持此系统: $OS_ID"
    exit 1
fi
sleep 1

echo "[2/8] 安装 KVM 及相关组件..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    echo "[2/8] 安装 KVM 及相关组件..."
    # 更新软件源
    sudo apt update -y
    # 安装 KVM 和相关工具
    sudo apt install -y \
        qemu-kvm libvirt-clients libvirt-daemon-system libvirt-clients bridge-utils virt-manager virt-v2v \
        libosinfo-bin ovmf libguestfs-tools
    # 启用 libvirt 服务
    sudo systemctl enable --now libvirtd || sudo systemctl enable --now libvirt-bin
fi
sleep 1


echo "[3/8] 开始优化 libvirt 配置..."
CONF_LIBVIRTD="/etc/libvirt/libvirtd.conf"
# 备份配置文件
cp -p "$CONF_LIBVIRTD" "${CONF_LIBVIRTD}.$(date +%F_%H%M%S).bak"
echo "已备份 libvirtd.conf 到 ${CONF_LIBVIRTD}.$(date +%F_%H%M%S).bak"
# 禁用 TLS、禁用 TCP（本地使用 Unix socket 即可）、关闭 libvirt TCP 监听功能。
sed -i 's/^#\?\s*listen_tls\s*=.*/listen_tls = 0/' "$CONF_LIBVIRTD"
sed -i 's/^#\?\s*tcp_port\s*=.*/tcp_port = ""/' "$CONF_LIBVIRTD"
sed -i 's/^#\?\s*listen_tcp\s*=.*/listen_tcp = 0/' "$CONF_LIBVIRTD"
# 日志
sed -i 's@^#\?\s*log_outputs\s*=.*@log_outputs="1:file:/var/log/libvirt/libvirtd.log"@' "$CONF_LIBVIRTD"


# 检查是否已存在 qemu 用户
if id qemu &>/dev/null; then
    echo "用户 qemu 已存在"
else
    echo "用户 qemu 不存在，正在创建..."
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin --comment "QEMU virtualization user" qemu
    if id qemu &>/dev/null; then
        echo "用户 qemu 创建成功"
    else
        echo "用户 qemu 创建失败，请检查权限或系统用户限制"
        exit 1
    fi
fi



echo "[4/8] 开始优化 qemu 权限和安全..."
CONF_QEMU="/etc/libvirt/qemu.conf"
# 备份配置文件
cp -p "$CONF_QEMU" "${CONF_QEMU}.$(date +%F_%H%M%S).bak"
echo "已备份 qemu.conf 到 ${CONF_QEMU}.$(date +%F_%H%M%S).bak"
sed -i 's/^#\?\s*user\s*=.*/user = "qemu"/' "$CONF_QEMU"
sed -i 's/^#\?\s*group\s*=.*/group = "qemu"/' "$CONF_QEMU"
sed -i 's/^#\?\s*security_driver\s*=.*/security_driver = "none"/' "$CONF_QEMU"
#security_driver 默认值通常是 selinux 或 apparmor，用于在宿主机层面给每个虚拟机进程加安全沙箱。

#日志
#sudo journalctl -xeu libvirtd
#sudo cat /var/log/libvirt/libvirtd.log

systemctl daemon-reexec
systemctl daemon-reload
systemctl restart libvirtd

echo "[5/8] 启动并检查 libvirtd 服务..."
systemctl enable --now libvirtd
systemctl status libvirtd --no-pager
sleep 1

#######################################
# QEMU 源码编译
#######################################
echo "检测 QEMU 安装情况..."

if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        echo "qemu-system-x86_64 未安装，请先安装 QEMU。"
        exit 1
    else
        echo "qemu-system-x86_64 已安装"
    fi
fi




# 获取系统 QEMU 版本
QEMU_VERSION=$(qemu-system-x86_64 --version | head -n1 | awk '{print $4}')
echo "当前系统 QEMU 版本：$QEMU_VERSION"
echo "==================== [是否需要 QEMU 编译升级，增加AIO等新功能] ===================="

# 提示是否升级
read -p "是否重新编译 QEMU-KVM？[Y/n]: " enable_build
if [[ "$enable_build" =~ ^[Nn]$ ]]; then
    echo "已禁用编译升级"
    exit 0
else
    echo "开始安装依赖并编译 QEMU..."
fi

QEMU_PKGNAME="qemu-kvm-suhu"
PREFIX="/usr/local/qemu"
#BUILD_DIR="$HOME/qemu-${QEMU_VERSION}/build"
BUILD_DIR="/opt/qemu-${QEMU_VERSION}/build"


echo "[1/8] 安装编译依赖..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    sudo apt update
    sudo apt install -y \
      git build-essential libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev \
      ninja-build meson python3-pip libnfs-dev libiscsi-dev libaio-dev liburing-dev libbluetooth-dev \
      libcap-ng-dev libcurl4-openssl-dev libssh-dev libvte-2.91-dev libgtk-3-dev \
      libspice-server-dev libusb-1.0-0-dev libusbredirparser-dev libseccomp-dev \
      liblzo2-dev librbd-dev librados-dev libibverbs-dev libnuma-dev libsnappy-dev \
      libbz2-dev libzstd-dev libpam0g-dev libsasl2-dev libselinux1-dev \
      libepoxy-dev libpulse-dev libjack-jackd2-dev libasound2-dev \
      libdrm-dev libgbm-dev libudev-dev \
      librdmacm-dev libibumad-dev libdevmapper-dev checkinstall cmake
fi

echo "[2/8] 下载 QEMU 源码..."
cd /opt
OFFICIAL_BASE="https://download.qemu.org"
BACKUP_BASE="http://10.53.123.144/kvm"

# 下载函数
download_qemu() {
    local base_url="$1"
    local tar_name="qemu-${QEMU_VERSION}.tar.xz"
    local url="${base_url}/${tar_name}"

    echo "尝试下载 QEMU 源码：$url"
    if wget --no-check-certificate -c --tries=5 "$url"; then
        echo "下载成功：$url"
        return 0
    else
        echo "下载失败：$url"
        return 1
    fi
}

cd /opt
# 先尝试官方站点
if ! download_qemu "$OFFICIAL_BASE"; then
    echo "官方下载失败，尝试从局域网备用地址下载..."
    if ! download_qemu "$BACKUP_BASE"; then
        echo "从局域网也下载失败，请检查网络或手动下载。"
        exit 1
    fi
fi

echo "QEMU 下载完成：qemu-${QEMU_VERSION}.tar.xz"
tar -Jxvf qemu-${QEMU_VERSION}.tar.xz 
cd qemu-${QEMU_VERSION}

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
  --enable-linux-io-uring \
  --enable-libnfs \
  --enable-opengl \
  --enable-guest-agent 
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
set -euo pipefail

# ---------- 检测系统类型 ----------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    echo "检测到系统类型：$PRETTY_NAME"
else
    echo "无法检测系统类型，请确认系统是否受支持"
    exit 1
fi

# ---------- 检测启动方式 ----------
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="EFI"
    echo "检测到启动方式：EFI 模式"
else
    BOOT_MODE="BIOS"
    echo "检测到启动方式：Legacy BIOS 模式"
fi

# ---------- 检测 CPU ----------
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

# ---------- 启用嵌套虚拟化 ----------
if [[ "$CPU_VENDOR" == "intel" ]]; then
    echo "启用 Intel 嵌套虚拟化..."
    modprobe -r kvm_intel || true
    modprobe kvm_intel nested=1
    echo 'options kvm_intel nested=1' | tee /etc/modprobe.d/kvm-nested.conf
else
    echo "启用 AMD 嵌套虚拟化..."
    modprobe -r kvm_amd || true
    modprobe kvm_amd nested=1
    echo 'options kvm_amd nested=1' | tee /etc/modprobe.d/kvm-nested.conf
fi

# ---------- 配置 IOMMU ----------
echo
echo "启用 IOMMU 支持..."

GRUB_FILE=""
if [[ "$OS_ID" =~ ^(ubuntu|debian)$ ]]; then
    GRUB_FILE="/etc/default/grub"
elif [[ "$OS_ID" == "rocky" ]]; then
    if [[ "$BOOT_MODE" == "EFI" ]]; then
        GRUB_FILE="/etc/default/grub"
    else
        GRUB_FILE="/etc/default/grub"
    fi
else
    echo "不支持的系统类型：$OS_ID"
    exit 1
fi

if [[ "$CPU_VENDOR" == "intel" ]]; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt"/' $GRUB_FILE || \
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/d' $GRUB_FILE && echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt"' >> $GRUB_FILE
else
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt"/' $GRUB_FILE || \
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/d' $GRUB_FILE && echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt"' >> $GRUB_FILE
fi

# ---------- 更新 GRUB ----------
echo "更新 GRUB 配置..."
if [[ "$OS_ID" =~ ^(ubuntu|debian)$ ]]; then
    update-grub
elif [[ "$OS_ID" == "rocky" ]]; then
    if [[ "$BOOT_MODE" == "EFI" ]]; then
        grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg
    else
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
fi

# ---------- 配置 VFIO ----------
echo
echo "配置 VFIO 模块..."
tee /etc/modules-load.d/vfio.conf > /dev/null <<EOF
vfio
vfio_iommu_type1
vfio_pci
EOF

modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci
lsmod | grep vfio || echo "VFIO 模块未正确加载"

# ---------- 屏蔽主机显卡 ----------
echo
echo "屏蔽主机 NVIDIA 驱动..."
tee /etc/modprobe.d/blacklist-nvidia.conf > /dev/null <<EOF
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist rivafb
EOF

# ---------- 更新 initramfs ----------
echo
echo "更新 initramfs..."
if [[ "$OS_ID" =~ ^(ubuntu|debian)$ ]]; then
    update-initramfs -u
elif [[ "$OS_ID" == "rocky" ]]; then
    dracut -f
fi

echo
echo "=============================================="
echo "配置完成！请执行以下命令重启系统生效："
echo "sudo reboot"
echo "=============================================="
