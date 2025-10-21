#!/bin/bash
# =========================================
# Rocky安装KVM
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
if [[ "$OS_ID" =~ (rocky|rhel) ]]; then
    dnf makecache -y || yum makecache -y
else
    echo "暂不支持此系统: $OS_ID"
    exit 1
fi
sleep 1


echo "[2/8] 安装 KVM 及相关组件..."
if [[ "$OS_ID" =~ (rocky|rhel|centos) ]]; then
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


systemctl daemon-reexec
systemctl daemon-reload
systemctl restart libvirtd

echo "[5/8] 启动并检查 libvirtd 服务..."
systemctl enable --now libvirtd
systemctl status libvirtd --no-pager
sleep 1


#######################################
if [[ "$OS_ID" == "rocky" ]]; then
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


#######################################
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