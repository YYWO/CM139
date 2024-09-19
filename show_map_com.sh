#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")") # 获取当前路径
INPUT_LOG="$SCRIPT_DIR/./logs/getcom/log_$(date '+%Y-%m-%d_%H-%M-%S').log"
mkdir -p "$SCRIPT_DIR/./logs/getcom"
exec > >(tee -a "$INPUT_LOG") 2>&1

cat_cmd="/bin/cat"  # 使用系统自带的 cat 命令
echo_cmd="/bin/echo"  # 使用系统自带的 echo 命令
green="\033[32m"  # 设置绿色字体
yellow="\033[33m" # 设置黄色字体
nc="\033[0m"      # 重置颜色

# 获取 IPv6 地址的函数
get_ipv6_address() {
    ipv6_address=$(curl -s 6.ipw.cn)
    if [ -z "$ipv6_address" ]; then
        $echo_cmd -e "${yellow}未能获取 IPv6 地址${nc}" >>"$INPUT_LOG"
        ipv6_address="无"
    fi
    echo "$ipv6_address"
}

# 获取端口占用情况的函数
get_port_occupation() {
    local base_port=$1
    local port_occupation=$(netstat -tlnp 2>/dev/null | grep ":$base_port")
    if [ -n "$port_occupation" ]; then
        local process=$(echo "$port_occupation" | awk '{sub(/[0-9]+\//, "", $NF); print $NF; exit}')
        echo "被进程 $process 占用"
    else
        echo "未被占用"
    fi
}

# 函数:根据脚本运行环境选择获取端口的方法
detect_method_get_external_com() {
    n_file="/data/local/qcom/log/boxotaLog.txt" # 移动云手机(n:normal)
    u_file="/data/local/tmp/portmap.json"       # 移动云手机极致版(u:ultimate)
    if [ -f "$n_file" ]; then
        $echo_cmd -e "脚本运行在移动云手机的云手机上" >>"$INPUT_LOG"
        get_n_com
    elif [ -f "$u_file" ]; then
        $echo_cmd -e "脚本运行在移动云手机极致版的云手机上" >>"$INPUT_LOG"
        get_u_com
    fi
}

# 函数:移动云手机获取公网端口
get_n_com() {
    # 使用 cat 命令读取日志并解析最后一个 "aport":10000 的地址和端口信息
    result=$($cat_cmd "$n_file" | awk '/"aport":10000/ {match($0, /"external":\{"address":"[^"]+","aport":[0-9]+/); if (RSTART > 0) print substr($0, RSTART, RLENGTH)}' | tail -1)
    
    # 提取公网 IP 和端口号
    n_external_address=$(echo "$result" | awk -F'"address":"' '{print $2}' | awk -F'"' '{print $1}')
    n_external_aport=$(echo "$result" | awk -F'"aport":' '{print $2}')
    
    # 获取 IPv6 地址
    n_ipv6_address=$(get_ipv6_address)
    
    # 检查是否成功提取到正确的 IP 和端口
    if [ -z "$n_external_address" ] || [ -z "$n_external_aport" ]; then
        $echo_cmd -e "${yellow}未找到正确的公网 IP 或端口，请检查日志文件格式${nc}" >>"$INPUT_LOG"
        exit 1
    fi

    # 记录端口映射及占用情况
    port_mapping_info=""
    for i in {0..4}; do
        base_port=$((10000 + i))
        port_status=$(get_port_occupation $base_port)
        port_mapping_info+="内网端口: ${base_port} =====> 公网端口: $((n_external_aport + i)) ${port_status}\n"
    done

    # 输出解析结果到日志
    $echo_cmd -e "IPv4地址: ${n_external_address}\nIPv6地址: ${n_ipv6_address}\n\n端口映射及占用情况:\n${port_mapping_info}\n-------检-测-时-间-------\n$(date "+%Y-%m-%d %H:%M:%S")" >>"$INPUT_LOG"
    
    # 保存端口映射信息到文件
    echo -e "IPv4地址: ${n_external_address}\nIPv6地址: ${n_ipv6_address}\n\n端口映射及占用情况:\n${port_mapping_info}\n-------检-测-时-间-------\n$(date "+%Y-%m-%d %H:%M:%S")" | tee "$SCRIPT_DIR/./端口映射关系.txt" | tee -a "$INPUT_LOG"
    
    # 显示保存成功的信息
    $echo_cmd -e "${green}更多端口映射关系已保存到 ${yellow}$(dirname "$SCRIPT_DIR")/端口映射关系.txt ${green}中${nc}"
    # read -rp "按任意键退出"
    exit 0
}

# 函数:移动云手机极致版获取端口
get_u_com() {
    # 使用 cat 和原生工具解析JSON格式数据
    while read -r line; do
        case "$line" in
            *'"type":"10000"') u_external_aport_10000=$(echo "$line" | awk -F':' '{print $NF}' | tr -d ',');;
            *'"type":"10001"') u_external_aport_10001=$(echo "$line" | awk -F':' '{print $NF}' | tr -d ',');;
            *'"type":"10002"') u_external_aport_10002=$(echo "$line" | awk -F':' '{print $NF}' | tr -d ',');;
            *'"type":"10003"') u_external_aport_10003=$(echo "$line" | awk -F':' '{print $NF}' | tr -d ',');;
            *'"type":"10004"') u_external_aport_10004=$(echo "$line" | awk -F':' '{print $NF}' | tr -d ',');;
            *'"public_ip"') u_external_address=$(echo "$line" | awk -F'["]' '{print $4}');;
        esac
    done < "$u_file"
    
    # 获取 IPv6 地址
    u_ipv6_address=$(get_ipv6_address)
    
    # 记录端口映射及占用情况
    port_mapping_info=""
    for i in {0..4}; do
        base_port=$((10000 + i))
        port_status=$(get_port_occupation $base_port)
        port_mapping_info+="内网端口: ${base_port} =====> 公网端口: $((u_external_aport_10000 + i)) ${port_status}\n"
    done
    
    # 输出解析结果到日志
    echo -e "IPv4地址: ${u_external_address}\nIPv6地址: ${u_ipv6_address}\n\n端口映射及占用情况:\n${port_mapping_info}\n-------检-测-时-间-------\n$(date "+%Y-%m-%d %H:%M:%S")" | tee "$SCRIPT_DIR/./端口映射关系.txt" | tee -a "$INPUT_LOG"
    
    $echo_cmd -e "${green}更多端口映射关系已保存到 ${yellow}$(dirname "$SCRIPT_DIR")/端口映射关系.txt ${green}中${nc}"
}

# 执行函数
detect_method_get_external_com
