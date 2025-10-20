#!/usr/bin/env bash
# ===========================================================
# KVM Bond + Bridge 自动配置（Rocky/Kylin 专用版）目前无法使用
# 作者：asuhu
# ===========================================================

set -euo pipefail

# ========== 默认配置（可交互修改） ==========
BRIDGE_NAME="br0"
BOND_NAME="bond0"
BOND_MODE="active-backup"     # 可改为 802.3ad、balance-alb 等
MIIMON="100"
PRIMARY_SLAVE=""              # active-backup 可设置主用口，如 eno1

USE_DHCP=true
IP_ADDR="192.168.1.100/24"
GATEWAY="192.168.1.1"
DNS="114.114.114.114,8.8.8.8"

SLAVE_IFACES=("eno1" "eno2")

# ========== 工具检测 ==========
require_root() {
  [[ $EUID -eq 0 ]] || { echo -e "\033[1;31m[错误]\033[0m 请以 root 运行"; exit 1; }
}
check_nmcli() {
  command -v nmcli >/dev/null 2>&1 || { echo -e "\033[1;31m[错误]\033[0m 未检测到 nmcli，退出。"; exit 1; }
  systemctl enable --now NetworkManager >/dev/null 2>&1 || true
  systemctl is-active --quiet NetworkManager || { echo -e "\033[1;31m[错误]\033[0m NetworkManager 未运行"; exit 1; }
}

# ========== 参数确认 ==========
confirm_or_read() {
  echo -e "\033[1;34m========== 网络参数确认 ==========\033[0m"
  read -r -p "Bond 接口名 [${BOND_NAME}]: " v; [[ -n "${v:-}" ]] && BOND_NAME="$v"
  read -r -p "Bridge 名称 [${BRIDGE_NAME}]: " v; [[ -n "${v:-}" ]] && BRIDGE_NAME="$v"
  read -r -p "Bond 模式 [${BOND_MODE}]: " v; [[ -n "${v:-}" ]] && BOND_MODE="$v"
  read -r -p "物理网卡(空格分隔) [${SLAVE_IFACES[*]}]: " v; [[ -n "${v:-}" ]] && SLAVE_IFACES=($v)
  read -r -p "是否使用 DHCP? (Y/n): " v; v=${v:-Y}; [[ "$v" =~ ^[Nn]$ ]] && USE_DHCP=false
  if ! $USE_DHCP; then
    read -r -p "静态 IP [${IP_ADDR}]: " v; [[ -n "${v:-}" ]] && IP_ADDR="$v"
    read -r -p "网关 [${GATEWAY}]: " v; [[ -n "${v:-}" ]] && GATEWAY="$v"
    read -r -p "DNS [${DNS}]: " v; [[ -n "${v:-}" ]] && DNS="$v"
  fi
  if [[ "$BOND_MODE" == "active-backup" ]]; then
    read -r -p "主用网口 primary（可空）[${PRIMARY_SLAVE}]: " v; [[ -n "${v:-}" ]] && PRIMARY_SLAVE="$v"
  fi
}

# ========== NetworkManager 操作函数 ==========
nm_con_exists() { nmcli -g NAME c show 2>/dev/null | grep -Fxq "$1"; }
nm_con_type()   { nmcli -g TYPE c show "$1" 2>/dev/null || true; }
nm_disable_ip() { nmcli c mod "$1" ipv4.method disabled ipv6.method ignore || true; }

configure_nmcli() {
  echo -e "\033[1;34m[信息]\033[0m 使用 NetworkManager 配置 bond + bridge ..."

  # 下线旧连接
  for c in "$BRIDGE_NAME" "br-slave-${BOND_NAME}" "$BOND_NAME"; do
    nmcli con down "$c" >/dev/null 2>&1 || true
  done

  # 删除类型错误的连接
  for c in "$BRIDGE_NAME" "$BOND_NAME" "br-slave-${BOND_NAME}"; do
    if nm_con_exists "$c"; then
      local t; t=$(nm_con_type "$c")
      case "$c" in
        "$BRIDGE_NAME") [[ "$t" != "bridge" ]] && nmcli con del "$c" ;;
        "$BOND_NAME") [[ "$t" != "bond" ]] && nmcli con del "$c" ;;
        "br-slave-${BOND_NAME}") [[ "$t" != "bridge-slave" ]] && nmcli con del "$c" ;;
      esac
    fi
  done

  # 启用物理接口并设为受管
  for nic in "${SLAVE_IFACES[@]}"; do
    ip link set "$nic" up || true
    nmcli device set "$nic" managed yes || true
  done

  # 创建 bond
  if ! nm_con_exists "$BOND_NAME"; then
    nmcli c add type bond ifname "$BOND_NAME" con-name "$BOND_NAME" \
      bond.options "mode=${BOND_MODE},miimon=${MIIMON}${PRIMARY_SLAVE:+,primary=${PRIMARY_SLAVE}},downdelay=200,updelay=200,fail_over_mac=1,link-monitoring=mii" \
      autoconnect yes
  else
    nmcli c mod "$BOND_NAME" bond.options "mode=${BOND_MODE},miimon=${MIIMON}${PRIMARY_SLAVE:+,primary=${PRIMARY_SLAVE}}" autoconnect yes
  fi
  nm_disable_ip "$BOND_NAME"

  # 添加 bond-slave
  for nic in "${SLAVE_IFACES[@]}"; do
    nmcli con delete "$nic" >/dev/null 2>&1 || true
    nmcli c add type bond-slave ifname "$nic" master "$BOND_NAME" con-name "$nic" autoconnect yes
    nm_disable_ip "$nic"
  done

  # 创建 bridge
  if ! nm_con_exists "$BRIDGE_NAME"; then
    nmcli c add type bridge ifname "$BRIDGE_NAME" con-name "$BRIDGE_NAME" autoconnect yes
  fi
  nmcli c mod "$BRIDGE_NAME" bridge.stp no bridge.forward-delay 0 connection.autoconnect-slaves yes ipv6.method ignore
  if $USE_DHCP; then
    nmcli c mod "$BRIDGE_NAME" ipv4.method auto
  else
    nmcli c mod "$BRIDGE_NAME" ipv4.method manual ipv4.addresses "$IP_ADDR" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS"
  fi

  # 将 bond 加入 bridge
  if ! nm_con_exists "br-slave-${BOND_NAME}"; then
    nmcli c add type bridge-slave ifname "$BOND_NAME" master "$BRIDGE_NAME" con-name "br-slave-${BOND_NAME}" autoconnect yes
  fi

  echo -e "\033[1;34m[信息]\033[0m 启动顺序：bond -> br-slave -> bridge ..."
  nmcli con up "$BOND_NAME" || true
  nmcli con up "br-slave-${BOND_NAME}" || true
  nmcli con up "$BRIDGE_NAME" || true

  sleep 3
  ip link set "$BRIDGE_NAME" up
  ip link set "$BOND_NAME" up
  for nic in "${SLAVE_IFACES[@]}"; do ip link set "$nic" up; done

  echo -e "\033[1;32m[成功]\033[0m Bond + Bridge 已配置完成。"
  echo -e "\n\033[1;34m[状态检查]\033[0m"
  ip -d link show "$BRIDGE_NAME" | grep -E 'state|bridge'
  nmcli -t -f NAME,TYPE,DEVICE,STATE c show --active | grep -E 'bridge|bond'
}

# ========== 主流程 ==========
main() {
  require_root
  check_nmcli
  confirm_or_read
  configure_nmcli

  echo
  echo -e "\033[1;36m[完成]\033[0m 若 br0 仍为 down，请检查物理链路、交换机端口或 bond 模式是否匹配。"
}

main "$@"