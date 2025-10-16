#!/bin/bash
# ------------------------------------------------------------
# 虚拟机 ISO 管理脚本 detach_iso.sh
# 用法：
#   bash detach_iso.sh <Instance_Name>   # 卸载单个虚拟机 ISO
#   bash detach_iso.sh all               # 批量卸载所有虚拟机 ISO
#   bash detach_iso.sh list              # 列出所有虚拟机 ISO 挂载情况
# ------------------------------------------------------------

logfile="/root/instance.log"
detach_time=$(date "+Instance Detach Time %Y-%m-%d %H:%M.%S")

# 卸载指定虚拟机 ISO 的函数
detach_iso_func() {
    local name="$1"
    local status
    local iso_info

    # 获取虚拟机状态
    status=$(virsh domstate "$name" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo -e "\e[1;33;41m 虚拟机 $name 不存在！\e[0m"
        return
    fi

    # 获取当前挂载的 ISO 信息
    iso_info=$(virsh domblklist "$name" | awk '/hda|sda/ {print $1, $2}')

    # 判断是否运行中
    if echo "$status" | grep -Eq "running|运行中"; then
        virsh change-media "$name" hda --eject --live --config --force 2>/dev/null
        virsh change-media "$name" sda --eject --live --config --force 2>/dev/null
        echo -e "\e[1;32m 成功卸载运行中虚拟机 [$name] 的 ISO。\e[0m"
    else
        virsh change-media "$name" hda --eject --config --force 2>/dev/null
        virsh change-media "$name" sda --eject --config --force 2>/dev/null
        echo -e "\e[1;32m 成功卸载已关闭虚拟机 [$name] 的 ISO。\e[0m"
    fi

    # 输出卸载的 ISO 信息
    if [[ -n "$iso_info" ]]; then
        echo "卸载的镜像信息：$iso_info"
    else
        echo "虚拟机 [$name] 未挂载 ISO。"
    fi

    # 写入日志
    echo "${detach_time} - Instance Name ${name} - ISO Info: ${iso_info}" >> "$logfile"
}

# 列出所有虚拟机的 ISO 挂载信息
list_iso_func() {
    echo -e "\e[1;34m 当前虚拟机 ISO 挂载情况：\e[0m"
    vm_list=$(virsh list --all --name | grep -v '^$')
    if [[ -z "$vm_list" ]]; then
        echo -e "\e[1;33m 未找到任何虚拟机。\e[0m"
        return
    fi

    for vm in $vm_list; do
        status=$(virsh domstate "$vm" 2>/dev/null)
        iso_info=$(virsh domblklist "$vm" | awk '/hda|sda/ {print $1, $2}')
        echo -e "\n\e[1;36m 虚拟机：$vm\e[0m"
        echo "状态：$status"
        if [[ -n "$iso_info" ]]; then
            echo -e "ISO 挂载信息：\n$iso_info"
        else
            echo "未挂载任何 ISO 镜像。"
        fi
    done
    echo
}

# 主逻辑
name="$1"

if [[ -z "$name" ]]; then
    echo -e "\e[1;33;41m 请指定虚拟机名称或使用 'all'、'list' 参数！\e[0m"
    echo "用法示例："
    echo "  bash detach_iso.sh VM10     # 卸载单个虚拟机 ISO"
    echo "  bash detach_iso.sh all      # 批量卸载所有虚拟机 ISO"
    echo "  bash detach_iso.sh list     # 列出所有虚拟机的 ISO 挂载情况"
    exit 1
fi

case "$name" in
    all)
        echo -e "\e[1;34m 开始批量卸载所有虚拟机的 ISO ...\e[0m"
        vm_list=$(virsh list --all --name | grep -v '^$')
        if [[ -z "$vm_list" ]]; then
            echo -e "\e[1;33m 未找到任何虚拟机！\e[0m"
            exit 0
        fi

        for vm in $vm_list; do
            echo -e "\n\e[1;36m 处理虚拟机：$vm \e[0m"
            detach_iso_func "$vm"
        done
        echo -e "\n\e[1;32m 所有虚拟机的 ISO 已卸载完成！\e[0m"
        ;;
    list)
        list_iso_func
        ;;
    *)
        detach_iso_func "$name"
        ;;
esac