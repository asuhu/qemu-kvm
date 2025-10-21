#!/bin/bash
set -e

# ========== 参数配置 ==========
IP="10.53.220.243/24"
GATEWAY="10.53.220.254"
DNS="114.114.114.114"
NIC1="eno1"
NIC2="eno2"

echo "[INFO] 停止原有连接..."
nmcli connection down $NIC1 || true
nmcli connection down $NIC2 || true
nmcli connection down bond0 || true
nmcli connection down br0 || true

echo "[INFO] 删除旧的 bond/br0 配置（如存在）..."
nmcli connection delete $NIC1 || true
nmcli connection delete $NIC2 || true
nmcli connection delete bond0 || true
nmcli connection delete br0 || true
nmcli connection delete bond0-${NIC1} || true
nmcli connection delete bond0-${NIC2} || true
nmcli connection delete br0-bond0 || true

# Reload to apply deletions
nmcli connection reload

# ========== 创建 bond0（active-backup 模式） ==========
echo "[INFO] 创建 bond0（active-backup 模式 with miimon and primary）..."
nmcli connection add type bond con-name bond0 ifname bond0 mode active-backup miimon 100 primary ${NIC1}

# 设置 bond0 不获取 IP（仅供桥接使用）
nmcli connection modify bond0 ipv4.method disabled ipv6.method ignore

# ========== 添加从接口 ==========
echo "[INFO] 将物理网卡添加到 bond0..."
nmcli connection add type ethernet con-name bond0-${NIC1} ifname ${NIC1} master bond0
nmcli connection add type ethernet con-name bond0-${NIC2} ifname ${NIC2} master bond0

# ========== 创建桥接 br0 ==========
echo "[INFO] 创建网桥 br0..."
nmcli connection add type bridge con-name br0 ifname br0 bridge.stp no  # Disable STP to avoid delays

# 设置静态 IP
nmcli connection modify br0 ipv4.addresses "$IP" \
    ipv4.gateway "$GATEWAY" \
    ipv4.dns "$DNS" \
    ipv4.method manual ipv6.method ignore

# 启用自动端口激活和桥接自动连接
nmcli connection modify br0 connection.autoconnect-ports true
nmcli connection modify br0 connection.autoconnect true

# ========== 将 bond0 加入 br0 ==========
echo "[INFO] 将 bond0 加入 br0（修改现有连接）..."
nmcli connection modify bond0 controller br0

# ========== 启动连接 ==========
echo "[INFO] 启动连接（slaves 先，然后 bond，然后 br0）..."
nmcli connection up bond0-${NIC1}
nmcli connection up bond0-${NIC2}
nmcli connection up bond0
nmcli connection up br0

# Reload and restart if needed
nmcli connection reload
systemctl restart NetworkManager || true  # Optional, but helps clear conflicts

echo "[SUCCESS] Bond + Bridge 网络配置完成！"
nmcli connection show --active
ip route show
cat /proc/net/bonding/bond0