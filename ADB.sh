#!/bin/bash
#请在MT管理器使用扩展包环境执行，使用root权限执行


# 获取本机的IPv4地址，最大等待时间5秒
ipv4_address=$(curl -s --max-time 5 ip.sb -4)

# 端口选择函数
choose_port() {
    for port in 9999; do
        if ! lsof -i:$port &> /dev/null; then
            echo $port
            return
        fi
    done
    sudo killall -9 $(lsof -t -i:9999)
    echo 9999
}

# 基础端口选择
base_port=$(choose_port)


last_digit=$(ifconfig wlan0 | grep 'inet ' | awk '{print $2}' | cut -d'.' -f4)


mapped_port=$((base_port + (last_digit - 2) * 5))

# 需要root权限
[ "$(id -u)" != "0" ] && echo "此脚本必须以root权限运行" && exit 1

# 定义build.prop文件路径
prop_file="/system/build.prop"

# 定义要添加的属性
declare -A properties=(
    ["service.adb.tcp.port"]="service.adb.tcp.port=$base_port"
    ["ro.secure"]="ro.secure=1"
    ["ro.adb.secure"]="ro.adb.secure=1"
    ["ro.debuggable"]="ro.debuggable=0"
    ["persist.service.adb.enable"]="persist.service.adb.enable=1"
    ["persist.sys.usb.config"]="persist.sys.usb.config=mtp,adb"
)

# 用于存储更新后的内容的临时文件
temp_file=$(mktemp)

# 删除已存在的指定行
while IFS= read -r line; do
    skip=false
    for key in "${!properties[@]}"; do
        if [[ "$line" == $key=* ]]; then
            skip=true
            break
        fi
    done
    if [ "$skip" = false ]; then
        echo "$line" >> "$temp_file"
    fi
done < "$prop_file"

# 添加新的属性
for key in "${!properties[@]}"; do
    echo "${properties[$key]}" >> "$temp_file"
done

# 将临时文件内容复制回build.prop
mv "$temp_file" "$prop_file"


echo "远程ADB已启用，请重启云手机后使用以下地址连接:"
echo "${ipv4_address}:${mapped_port}"
