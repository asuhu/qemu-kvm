#!/bin/bash
set -e
set -o pipefail

echo "[1/8] 安装 KVM 基础组件..."
# 保留原有 yum 安装命令
yum install -y qemu-kvm libvirt virt-install bridge-utils virt-manager

echo "[2/8] 启动 libvirtd 服务并开机自启..."
systemctl enable --now libvirtd
systemctl status libvirtd --no-pager

echo "[3/8] 优化 libvirt 配置 (开启 TCP 监听、日志、提高客户端连接上限)..."
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

echo "[4/8] 优化 QEMU 权限和安全..."
CONF_QEMU="/etc/libvirt/qemu.conf"
sed -i 's/^#\?\s*user\s*=.*/user = "qemu"/' "$CONF_QEMU"
sed -i 's/^#\?\s*group\s*=.*/group = "qemu"/' "$CONF_QEMU"
sed -i 's/^#\?\s*security_driver\s*=.*/security_driver = "none"/' "$CONF_QEMU"
#security_driver 默认值通常是 selinux 或 apparmor，用于在宿主机层面给每个虚拟机进程加安全沙箱。

echo "[5/8] 调整系统内核参数优化虚拟机性能..."
# 删除原有配置
sed -i '/vm.swappiness/d' /etc/sysctl.conf
sed -i '/vm.dirty_ratio/d' /etc/sysctl.conf
sed -i '/vm.dirty_background_ratio/d' /etc/sysctl.conf
sed -i '/kernel.sched_min_granularity_ns/d' /etc/sysctl.conf
sed -i '/kernel.sched_wakeup_granularity_ns/d' /etc/sysctl.conf

# 添加优化参数
cat <<EOF | sudo tee -a /etc/sysctl.conf >/dev/null
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000
EOF

sysctl -p

echo "[7/8] 启动 VFIO 支持 (用于直通设备)..."
cat <<EOF | tee /etc/modules-load.d/vfio.conf
vfio
vfio_iommu_type1
vfio_pci
EOF
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci
lsmod | grep vfio || echo "VFIO 模块未正确加载"

echo "[8/8] 重启 libvirtd 生效配置..."
systemctl restart libvirtd
systemctl status libvirtd --no-pager

echo "麒麟 Linux KVM 安装与优化完成！"