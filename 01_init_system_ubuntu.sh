#!/bin/bash

echo "[1/12] 优化系统升级..."
sudo sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
sudo sed -i 's/^APT::Periodic::Update-Package-Lists.*/APT::Periodic::Update-Package-Lists "0";/' /etc/apt/apt.conf.d/20auto-upgrades
sudo sed -i 's/^APT::Periodic::Unattended-Upgrade.*/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades
sleep 1
echo "[2/12] 优化SSH配置.."
sudo sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sleep 1
echo "[3/12] 优化History命令.."
sudo cat > /etc/profile.d/lnamp.sh << "EOF"
# 设置历史记录大小
HISTFILESIZE=1000000000
HISTSIZE=100000000

# 追加命令到历史文件，确保实时记录历史命令
PROMPT_COMMAND="history -a"

# 历史记录时间格式
HISTTIMEFORMAT="%Y-%m-%d_%H:%M:%S `whoami` "

# 自定义命令提示符
PS1="\[\e[37;40m\][\[\e[32;40m\]\u\[\e[37;40m\]@\h \[\e[35;40m\]\W\[\e[0m\]]\$ "

# 定义常用别名
alias l='ls -AFhlt --color=auto'
alias lh='ls -AFhlt --color=auto | head'
EOF
sleep 1
echo "[4/12] 软件升级.."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
git build-essential vim curl htop gcc python3 python3-pip openjdk-11-jdk net-tools nmap vlc ffmpeg gimp inkscape libreoffice zip unzip tar sysstat strace \
fail2ban clamav libssl-dev libcurl4-openssl-dev ntpdate chrony iftop iotop
sudo apt remove vim-common -y && sudo apt install vim -y
sleep 1
echo "[5/12] 完全禁用 Cloud-Init.."
sudo touch /etc/cloud/cloud-init.disabled
sleep 1
echo "[6/12] 优化其他杂项.."
sudo echo "* soft nofile 65535" >> /etc/security/limits.conf
sudo echo "* hard nofile 65535" >> /etc/security/limits.conf
sudo sed -i '/^#DefaultLimitNOFILE=/c\DefaultLimitNOFILE=65535' /etc/systemd/user.conf
sudo sed -i '/^#DefaultLimitNOFILE=/c\DefaultLimitNOFILE=65535' /etc/systemd/system.conf
sleep 1
echo "[7/12] 优化内核参数..."
cat <<EOF | sudo tee /etc/sysctl.d/99-custom.conf
# 启用TCP连接重用，加快TIME_WAIT释放
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# 增加文件句柄数上限
fs.file-max = 2097152

# 增加网络缓冲区
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 防止SYN攻击
net.ipv4.tcp_syncookies = 1

# 禁止ICMP广播请求
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 启用IP转发（如部署K8s或NAT用途）
net.ipv4.ip_forward = 1
EOF
# 应用配置
sudo sysctl --system

sleep 1
echo "[8/12] 系统服务与启动优化..."

# 关闭不常用服务
sudo systemctl disable apt-daily.service apt-daily-upgrade.service
sudo systemctl disable motd-news.service
sudo systemctl mask snapd.service snapd.socket

# 限制日志占用空间
sudo mkdir -p /etc/systemd/journald.conf.d
cat <<EOF | sudo tee /etc/systemd/journald.conf.d/00-custom.conf
[Journal]
SystemMaxUse=2000M
SystemMaxFileSize=500M
MaxRetentionSec=180day
Compress=yes
EOF
sudo systemctl restart systemd-journald

# 禁用 snap 自动更新（可选）
sudo systemctl stop snapd
sudo systemctl disable snapd

# 加快开机启动时间
sudo systemctl mask systemd-udev-settle.service
sudo systemctl mask systemd-networkd-wait-online.service

# 设置时区并同步时间
sudo timedatectl set-timezone Asia/Shanghai
sudo systemctl enable chronyd
sudo systemctl restart chronyd

sleep 1
echo "[9/12] 安装并配置 chrony 使用阿里云 NTP 服务器..."

sudo timedatectl set-timezone Asia/Shanghai

# 安装 chrony 时间同步服务
sudo apt install -y chrony

# 设置阿里云 NTP 服务器
sudo sed -i 's|^pool .*|server ntp.aliyun.com iburst|' /etc/chrony/chrony.conf

# 启用并启动 chrony 服务
sudo systemctl enable chronyd
sudo systemctl restart chronyd

# 检查同步状态
sudo chronyc tracking
sudo chronyc sources
sudo chronyc -a makestep



echo "[10/12] 启用 BBR 加速（TCP性能）..."
sleep 1
# 启用 BBR（在 4.9+ 内核下默认可用）
sudo modprobe tcp_bbr
echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/modules.conf

# 添加 sysctl 配置
cat <<EOF | sudo tee /etc/sysctl.d/99-bbr.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

sudo sysctl --system


echo "[16/9] 安装 fio 和 stress-ng（压力测试工具）..."

sudo apt install -y fio stress-ng



echo "[11/12] 安装并配置 SNMP 服务（允许指定 IP 获取所有信息）..."
sleep 1
# 安装 SNMP 服务及工具
sudo apt install -y snmp snmpd

# 备份配置
sudo cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bak

# 写入新配置
cat <<EOF | sudo tee /etc/snmp/snmpd.conf
# 设置社区字符串（只读），只允许来自 10.53.201.101 的访问
rocommunity ztzbPublic 10.53.201.101

# 设置系统信息（可选）
sysLocation IDC
sysContact ops@example.com

# 监听所有接口的 UDP 161 端口（默认）
agentAddress udp:161

# 定义允许读取所有 OID 的视图
view    systemview    included   .1