#!/bin/bash
# ===========================================================
# KVM Bond + 桥接网络自动配置脚本（Ubuntu / Debian 专用）
# 作者：asuhu
# ===========================================================

set -euo pipefail

# ========== 通用变量 ==========
BRIDGE_NAME="br0"
BOND_NAME="bond0"
BOND_MODE="active-backup"  # 可修改为 balance-alb、balance-xor 等
USE_DHCP=true
STATIC_IP=""
GATEWAY=""
DNS=""
INTERFACES=()

# ========== 系统检测 ==========
echo -e "\033[1;34m[信息]\033[0m 检测系统类型中..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
else
    echo -e "\033[1;31m[错误]\033[0m 无法检测系统类型。"
    exit 1
fi

if [[ ! "$OS_ID" =~ ^(ubuntu|debian)$ ]]; then
    echo -e "\033[1;31m[错误]\033[0m 当前系统 ($OS_ID) 不受支持，仅支持 Ubuntu / Debian。"
    exit 1
fi

echo -e "\033[1;32m[OK]\033[0m 检测到系统：$PRETTY_NAME"

# ========== 关闭 cloud-init 网络管理 ==========
CLOUD_CFG="/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"
if [ ! -f "$CLOUD_CFG" ]; then
    echo "network: {config: disabled}" | sudo tee "$CLOUD_CFG" >/dev/null
    echo -e "\033[1;33m[注意]\033[0m 已禁用 cloud-init 网络配置。"
fi

# ========== 用户输入 ==========
read -p "请输入桥接名称（默认 br0）: " input_bridge
[[ -n "$input_bridge" ]] && BRIDGE_NAME="$input_bridge"

read -p "请输入要加入 Bond 的物理接口名（多个以逗号分隔）: " input_ifs
IFS=',' read -r -a INTERFACES <<< "$input_ifs"

read -p "是否使用 DHCP 获取 IP？(Y/n): " use_dhcp
if [[ "$use_dhcp" =~ ^[Nn]$ ]]; then
    USE_DHCP=false
    read -p "请输入静态 IP 地址（如 192.168.1.100/24）: " STATIC_IP
    read -p "请输入网关地址: " GATEWAY
    read -p "请输入 DNS 服务器（多个用逗号分隔）: " DNS
fi

NETPLAN_FILE="/etc/netplan/99-custom-bridge.yaml"

# ========== 生成 Netplan 配置 ==========
echo -e "\033[1;34m[信息]\033[0m 正在生成 Netplan 配置..."
sudo cp -f "$NETPLAN_FILE" "${NETPLAN_FILE}.bak.$(date +%s)" 2>/dev/null || true

{
    echo "network:"
    echo "  version: 2"
    echo "  renderer: networkd"
    echo "  ethernets:"
    for iface in "${INTERFACES[@]}"; do
        echo "    ${iface}:"
        echo "      dhcp4: no"
    done
    echo "  bonds:"
    echo "    ${BOND_NAME}:"
    echo "      interfaces: [$(IFS=,; echo "${INTERFACES[*]}")]"
    echo "      parameters:"
    echo "        mode: $BOND_MODE"
    echo "        mii-monitor-interval: 100"
    echo "      dhcp4: no"
    echo "  bridges:"
    echo "    ${BRIDGE_NAME}:"
    echo "      interfaces: [${BOND_NAME}]"
    if $USE_DHCP; then
        echo "      dhcp4: yes"
    else
        echo "      addresses: [${STATIC_IP}]"
        echo "      gateway4: ${GATEWAY}"
        echo "      nameservers:"
        echo "        addresses: [${DNS}]"
    fi
    echo "      parameters:"
    echo "        stp: false"
    echo "        forward-delay: 0"
} | sudo tee "$NETPLAN_FILE" > /dev/null

echo -e "\033[1;32m[成功]\033[0m Netplan 配置已生成：$NETPLAN_FILE"

# ========== 应用配置 ==========
read -p "是否立即应用配置？(Y/n): " apply_now
if [[ ! "$apply_now" =~ ^[Nn]$ ]]; then
    sudo netplan apply
    echo -e "\033[1;32m[成功]\033[0m 网络配置已应用成功。"
else
    echo -e "\033[1;33m[提示]\033[0m 请稍后手动执行：sudo netplan apply"
fi

echo -e "\n\033[1;36m[完成]\033[0m Bond + 桥接配置脚本执行完毕。"