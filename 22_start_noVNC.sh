#!/bin/bash
# 自动启动 noVNC 并为每台虚拟机生成转发服务
# 记录详细日志：虚拟机名称、VNC端口、Web端口、访问地址
# 适用于 麒麟V10 / 欧拉 / CentOS / Ubuntu

NOVNC_DIR="/opt/noVNC"               # noVNC主目录（包含vnc.html）
LOG_DIR="/var/log/novnc"              # 单机日志目录
MAIN_LOG="/root/novnc.log"            # 汇总日志文件
CERT="/etc/ssl/novnc/novnc.crt"       # SSL证书
KEY="/etc/ssl/novnc/novnc.key"        # SSL私钥
BASE_PORT=6080                        # 起始 websockify 端口
WEB_PORT=$BASE_PORT

mkdir -p "$LOG_DIR"
touch "$MAIN_LOG"

echo "==============================" >> "$MAIN_LOG"
echo "$(date '+%Y-%m-%d %H:%M:%S') 启动 noVNC 服务扫描..." >> "$MAIN_LOG"

# 杀掉旧的 websockify 实例（防止重复）
pkill -f websockify 2>/dev/null

# 获取服务器IP地址（自动识别首个非127的IPv4）
HOST_IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i !~ /^127/) {print $i; exit}}')

# 检查SSL是否存在
SSL_OPT=""
if [[ -f "$CERT" && -f "$KEY" ]]; then
    SSL_OPT="--cert=$CERT --key=$KEY"
    PROTO="https"
else
    PROTO="http"
fi

# 遍历所有正在运行的虚拟机
for vm in $(virsh list --name); do
    if [ -z "$vm" ]; then
        continue
    fi

    # 获取VNC端口
    VNC_PORT=$(virsh dumpxml "$vm" | grep "graphics type='vnc'" | sed -n "s/.*port='\([0-9]*\)'.*/\1/p")

    if [[ -n "$VNC_PORT" && "$VNC_PORT" != "-1" ]]; then
        echo "启动 noVNC for VM: $vm (VNC:$VNC_PORT → Web:$WEB_PORT)"
        echo "[$(date '+%H:%M:%S')] VM: $vm | VNC: $VNC_PORT | Web: $WEB_PORT | URL: $PROTO://$HOST_IP:$WEB_PORT/vnc.html" >> "$MAIN_LOG"

        # 启动websockify转发
        nohup /usr/local/bin/websockify \
            --web=$NOVNC_DIR \
            $SSL_OPT \
            $WEB_PORT 127.0.0.1:$VNC_PORT \
            > "$LOG_DIR/$vm.log" 2>&1 &

        WEB_PORT=$((WEB_PORT + 1))
    else
        echo "无法获取 $vm 的 VNC 端口" | tee -a "$MAIN_LOG"
    fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') 所有 noVNC 服务已启动完成。" >> "$MAIN_LOG"
echo "==============================\n" >> "$MAIN_LOG"