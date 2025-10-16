#!/bin/bash
# ------------------------------------------------------------
# 虚拟机删除脚本 delete.sh
# 用法：bash delete.sh <Instance_Name>
# 功能：检测虚拟机是否运行，若运行则销毁并删除；否则直接删除定义。
# ------------------------------------------------------------

name="$1"
deletetime=$(date "+Instance Delete Time %Y-%m-%d %H:%M.%S")
logfile="/root/instance.log"

# 输入检查
if [[ -z "$name" ]]; then
    echo -e "\e[1;33;41m 请指定要删除的虚拟机名称！\e[0m"
    echo "用法示例：bash delete.sh <Instance_Name>"
    exit 1
fi

# 获取虚拟机状态
status=$(virsh domstate "$name" 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo -e "\e[1;33;41m 虚拟机 $name 不存在！\e[0m"
    exit 1
fi

# 判断是否为“running”或“运行中”
if echo "$status" | grep -Eq "running|运行中"; then
    # 运行中则先卸载介质再销毁
    virsh change-media "$name" hda --eject --live --config --force 2>/dev/null
    virsh change-media "$name" sda --eject --live --config --force 2>/dev/null
    virsh destroy "$name" 2>/dev/null
    virsh undefine "$name" --snapshots-metadata --remove-all-storage --nvram
    echo -e "\e[1;32m 成功删除正在运行的虚拟机：$name \e[0m"
else
    # 已关闭则直接删除
    virsh change-media "$name" hda --eject --config --force 2>/dev/null
    virsh change-media "$name" sda --eject --config --force 2>/dev/null
    virsh undefine "$name" --snapshots-metadata --remove-all-storage --nvram
    echo -e "\e[1;32m 成功删除已关闭的虚拟机：$name \e[0m"
fi

# 写入日志
echo "${deletetime} - Instance Name ${name}" >> "$logfile"