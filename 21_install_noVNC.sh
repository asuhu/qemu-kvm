#noVNC + websockify 安装脚本
#!/bin/bash
# ============================================
# 通用版 noVNC + websockify 安装脚本
# 适用系统：Ubuntu / 麒麟 Linux (Kylin V10/V11)
# ============================================

set -e

echo "=== 检查系统类型 ==="
OS_NAME=$(grep -E '^NAME=' /etc/os-release | cut -d'"' -f2)
echo "检测到系统：$OS_NAME"

# === 一、环境准备 ===
echo "=== 安装 Python3-pip、git、npm 等依赖 ==="
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y python3-pip git nodejs npm
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y install -y git python3 python3-venv gcc openssl-devel libffi-devel python3-pip git nodejs npm
else
    echo "未检测到 apt 或 yum，请手动安装依赖。"
    exit 1
fi

# === 二、安装 websockify ===
echo "=== 优先使用 pip 安装 websockify ==="
pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple

if sudo pip3 install -U websockify; then
    echo "websockify 安装成功"
else
    echo "pip 安装失败，尝试使用 git 获取 websockify 源码"
    cd /opt
    sudo git clone https://github.com/novnc/websockify.git || true
    sudo chown -R $(whoami):$(whoami) websockify
    cd websockify
    sudo python3 setup.py install
fi

echo "当前 websockify 路径：$(which websockify 2>/dev/null || echo '未检测到系统路径，请手动验证')"

# === 三、获取 noVNC 源码 ===
echo "=== 获取 noVNC 源码 ==="
cd /opt
if [ ! -d "/opt/noVNC" ]; then
    sudo git clone https://github.com/novnc/noVNC.git
fi
sudo chown -R $(whoami):$(whoami) /opt/noVNC

# === 四、可选构建（仅在 node/npm 可用时） ===
cd /opt/noVNC
if command -v npm >/dev/null 2>&1; then
    echo "=== 检测到 npm，尝试构建 noVNC 压缩包 ==="
    npm install
else
    echo "未检测到 npm，跳过构建步骤"
fi

echo "oVNC 与 websockify 安装完成"
echo "noVNC 目录：/opt/noVNC"