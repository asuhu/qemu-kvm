#!/bin/bash
# =========================================
# 一键安装 Cockpit + 虚拟机插件 + KVM
# 支持系统：Debian / Ubuntu / Rocky / CentOS / RHEL
# 作者：asuhu
# =========================================

set -euo pipefail

echo "==================== 系统检测 ===================="
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    echo "检测到系统: $PRETTY_NAME"
else
    echo "无法检测操作系统，请确认系统兼容 Debian/Ubuntu/Rocky/CentOS/RHEL"
    exit 1
fi

# ---------- 安装 Cockpit ----------
echo "==================== 安装 Cockpit ===================="
if [[ "$OS_ID" =~ ^(ubuntu|debian)$ ]]; then
    sudo apt update
    sudo apt install -y cockpit cockpit-machines \
        qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
elif [[ "$OS_ID" =~ ^(rocky|rhel|centos)$ ]]; then
    sudo dnf install -y cockpit cockpit-machines \
        qemu-kvm libvirt virt-install bridge-utils virt-manager
else
    echo "不支持的系统: $OS_ID"
    exit 1
fi

# ---------- 启动并启用 Cockpit ----------
echo "==================== 启用 Cockpit 服务 ===================="
sudo systemctl enable --now cockpit.socket

# ---------- 配置防火墙 ----------
if command -v firewall-cmd &>/dev/null; then
    echo "配置防火墙，放行 9090 端口..."
    sudo firewall-cmd --add-service=cockpit --permanent || true
    sudo firewall-cmd --reload || true
fi

# ---------- 检查 libvirt 服务 ----------
echo "==================== 启用 libvirt 服务 ===================="
sudo systemctl enable --now libvirtd || sudo systemctl enable --now libvirt-bin || true

# ---------- 安装完成提示 ----------
echo
echo "=============================================="
echo "安装完成！访问 Cockpit Web 界面："
echo "https://<服务器IP>:9090"
echo "使用系统 root 或 sudo 用户登录"
echo "在左侧导航栏即可管理虚拟机"
echo "=============================================="