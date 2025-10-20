#!/bin/bash
# =========================================
# KVM 安装和升级Ubuntu24.04
# 目前编译新版的QEMU-KVM还有问题
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
    echo "无法检测操作系统版本，请确认系统兼容 Ubuntu / RockyLinux"
    exit 1
fi

# 通用依赖初始化
echo "[1/8] 更新系统包..."
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    apt update -y
elif [[ "$OS_ID" =~ (rocky|rhel) ]]; then
    dnf makecache -y || yum makecache -y
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
elif [[ "$OS_ID" =~ (rocky|rhel|centos) ]]; then
    echo "[2/8] 安装 KVM 及相关组件..."  
    # 安装虚拟化宿主机基础组件（替代 @virt）
    sudo dnf -y groupinstall "Virtualization Host"
    # 安装额外组件
    sudo dnf install -y virt-install virt-manager virt-viewer virt-top virt-v2v \
                        qemu-kvm qemu-img libvirt libvirt-daemon-kvm \
                        libguestfs-tools edk2-ovmf
    # 启用 libvirtd 服务
    sudo systemctl enable --now libvirtd
fi
sleep 1


echo "[3/8] 开始优化 libvirt 配置..."
CONF_LIBVIRTD="/etc/libvirt/libvirtd.conf"
# 备份配置文件
cp -p "$CONF_LIBVIRTD" "${CONF_LIBVIRTD}.$(date +%F_%H%M%S).bak"
echo "已备份 libvirtd.conf 到 ${CONF_LIBVIRTD}.$(date +%F_%H%M%S).bak"
# 禁用 TLS、禁用 TCP（本地使用 Unix socket 即可）
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

#禁用配置 libvirtd 服务，使其通过 TCP 监听远程连接。
#LIBVIRTD_SERVICE="/etc/systemd/system/libvirtd.service.d/tcp.conf"
#mkdir -p "$(dirname "$LIBVIRTD_SERVICE")"
#cat > "$LIBVIRTD_SERVICE" <<EOF
#[Service]
#ExecStart=
#ExecStart=/usr/sbin/libvirtd --listen
#EOF

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

elif [[ "$OS_ID" == "rocky" ]]; then
    if [ -f /usr/libexec/qemu-kvm ]; then
        echo "/usr/libexec/qemu-kvm 存在"
        # 创建软链接到 /usr/bin
        sudo ln -sf /usr/libexec/qemu-kvm /usr/bin/qemu-kvm
        sudo ln -sf /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
        echo "已创建软链接到 /usr/bin"
    else
        echo "/usr/libexec/qemu-kvm 不存在，请先安装 QEMU。"
        exit 1
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

elif [[ "$OS_ID" =~ (rocky) ]]; then
    sudo dnf install -y epel-release
    sudo dnf config-manager --set-enabled crb
# 安装 QEMU 编译依赖，跳过无法安装或冲突的包
sudo dnf install -y \
    git gcc gcc-c++ make meson ninja-build python3-pip \
    glib2-devel pixman-devel zlib-devel libaio-devel libusb-devel \
    libcurl-devel libssh-devel libcap-ng-devel libnfs-devel \
    librbd-devel librados-devel rdma-core-devel numactl-devel libiscsi-devel \
    bzip2-devel snappy-devel libzstd-devel libdrm-devel \
    gtk3-devel libusbx-devel libepoxy-devel alsa-lib-devel cmake \
    --skip-broken
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

sudo dnf install -y python3-pip  # 确保 pip 可用
python3 -m pip install --user tomli

cd /tmp
git clone https://github.com/axboe/liburing.git
cd liburing
make
sudo make install
sudo ldconfig


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
elif [[ "$OS_ID" =~ (rocky) ]]; then
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