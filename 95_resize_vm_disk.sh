#!/bin/bash

createtime=$(date "+Instance Operation Time %Y-%m-%d %H:%M:%S")

# 列出所有虚拟机
echo "当前所有虚拟机列表："
virsh list --all
echo

# 选择虚拟机
read -p "请输入要扩容磁盘的虚拟机名称: " VM_NAME

# 检查虚拟机是否存在
if ! virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "虚拟机 $VM_NAME 不存在"
    exit 1
fi

# 获取虚拟机当前状态
VM_STATE=$(virsh domstate "$VM_NAME")
echo "虚拟机 $VM_NAME 当前状态: $VM_STATE"

# 如果虚拟机运行中，询问是否 destroy
if [[ "$VM_STATE" == "running" || "$VM_STATE" == "运行中" ]]; then
    read -p "虚拟机 $VM_NAME 正在运行，是否强制关机 (destroy) 扩容？(y/n, n 表示使用在线扩容) " DESTROY_CHOICE
    if [[ "$DESTROY_CHOICE" =~ ^[Yy]$ ]]; then
        virsh destroy "$VM_NAME"
        if [ $? -eq 0 ]; then
            echo "虚拟机 $VM_NAME 已强制关机"
            VM_STATE="shut off"
        else
            echo "虚拟机 $VM_NAME 强制关机失败，请检查"
            exit 1
        fi
    else
        echo "将使用在线扩容模式"
    fi
fi

# 列出虚拟机磁盘
echo "虚拟机 $VM_NAME 的磁盘列表："
virsh domblklist "$VM_NAME"
echo

read -p "请输入要扩容的磁盘设备名（例如 vda）: " DISK_DEV

# 获取磁盘文件路径
DISK_PATH=$(virsh domblklist "$VM_NAME" | awk -v dev="$DISK_DEV" '$1==dev {print $2}')

if [ -z "$DISK_PATH" ] || [ "$DISK_PATH" == "-" ]; then
    echo "磁盘 $DISK_DEV 不存在或没有绑定文件"
    exit 1
fi

# 获取当前磁盘大小 (GB)
CUR_SIZE=$(qemu-img info "$DISK_PATH" | awk -F'[()]' '/virtual size:/ {bytes=$2; gsub(/ bytes/,"",bytes); printf "%.0f\n", bytes/1024/1024/1024}')
echo "当前磁盘大小: ${CUR_SIZE}G"

read -p "请输入扩容后的新磁盘大小 (G, 必须大于 $CUR_SIZE): " NEW_SIZE

# 校验输入
if ! [[ "$NEW_SIZE" =~ ^[0-9]+$ ]]; then
    echo "请输入有效数字"
    exit 1
fi
if [ "$NEW_SIZE" -le "$CUR_SIZE" ]; then
    echo "新磁盘大小必须大于当前大小"
    exit 1
fi

# 执行扩容
echo "正在扩容 $VM_NAME 的 $DISK_DEV 到 ${NEW_SIZE}G..."

if [[ "$VM_STATE" == "running" || "$VM_STATE" == "运行中" ]]; then
    # 在线扩容
    virsh blockresize "$VM_NAME" "$DISK_DEV" "${NEW_SIZE}G"
    RESULT=$?
else
    # 离线扩容
    qemu-img resize "$DISK_PATH" "${NEW_SIZE}G"
    RESULT=$?
fi

# 处理扩容结果
if [ $RESULT -eq 0 ]; then
    echo "${createtime} - Instance Name $VM_NAME - 扩容成功！ - ${NEW_SIZE}G" >> /root/instance.log
    echo "扩容成功！"

    # 如果虚拟机之前是关机或 destroy，启动它
    if [[ "$VM_STATE" == "shut off" || "$VM_STATE" == "关闭" ]]; then
        echo "正在启动虚拟机 $VM_NAME ..."
        virsh start "$VM_NAME"
        if [ $? -eq 0 ]; then
            echo "虚拟机 $VM_NAME 已启动"
        else
            echo "虚拟机 $VM_NAME 启动失败，请检查"
        fi
    fi
else
    echo "${createtime} - Instance Name $VM_NAME - 扩容失败！" >> /root/instance.log
    echo "扩容失败！"
fi