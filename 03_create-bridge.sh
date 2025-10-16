#!/bin/bash

set -e

NETPLAN_FILE="/etc/netplan/99-custom-bridge.yaml"
BRIDGE_NAME="br0"
USE_DHCP=true
STATIC_IP=""
GATEWAY=""
DNS=""
INTERFACES=()

read -p "请输入桥接名称（默认 br0）: " input_bridge
if [[ -n "$input_bridge" ]]; then
  BRIDGE_NAME="$input_bridge"
fi

read -p "请输入要加入桥接的成员接口名（多个以逗号分隔）: " input_ifs
IFS=',' read -r -a INTERFACES <<< "$input_ifs"

read -p "是否使用 DHCP 获取 IP？(Y/n): " use_dhcp
if [[ "$use_dhcp" =~ ^[Nn]$ ]]; then
  USE_DHCP=false
  read -p "请输入静态 IP 地址（格式如 192.168.1.100/24）: " STATIC_IP
  read -p "请输入网关地址: " GATEWAY
  read -p "请输入 DNS 服务器（多个用逗号分隔）: " DNS
fi

echo "生成 Netplan 配置中..."

{
  echo "network:"
  echo "  version: 2"
  echo "  renderer: networkd"
  echo "  ethernets:"
  for iface in "${INTERFACES[@]}"; do
    echo "    ${iface}:"
    echo "      dhcp4: no"
  done
  echo "  bridges:"
  echo "    ${BRIDGE_NAME}:"
  echo -n "      interfaces: ["
  for iface in "${INTERFACES[@]}"; do
    echo -n "${iface}, "
  done | sed 's/, $//'
  echo "]"
  if $USE_DHCP; then
    echo "      dhcp4: yes"
    echo "      dhcp4-overrides:"
    echo "        route-metric: 100"
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

echo "Netplan 配置已生成: $NETPLAN_FILE"

read -p "是否立即应用配置？(Y/n): " apply_now
if [[ "$apply_now" =~ ^[Nn]$ ]]; then
  echo "请稍后手动执行：sudo netplan apply"
else
  echo "正在应用配置..."
  sudo netplan apply && echo "网络配置应用成功"
fi