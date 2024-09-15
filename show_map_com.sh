SCRIPT_DIR=$(dirname "$(readlink -f "$0")") # 获取当前路径
export LD_LIBRARY_PATH=$SCRIPT_DIR/../lib:${LD_LIBRARY_PATH:-}
INPUT_LOG="$SCRIPT_DIR/../logs/getcom/log_$(date '+%Y-%m-%d_%H-%M-%S').log"
mkdir -p "$SCRIPT_DIR/../logs/getcom"
exec > >(tee -a "$INPUT_LOG") 2>&1
grep="$SCRIPT_DIR"/../bin/grep
jq="$SCRIPT_DIR"/../bin/jq
echo="$SCRIPT_DIR"/../bin/echo
green="\033[32m"  #设置绿色字体。
yellow="\033[33m" #设置黄色字体。
nc="\033[0m"      #重置颜色


# 函数:根据脚本运行环境选择获取端口的方法
detect_method_get_external_com() {
    n_file="/data/local/qcom/log/boxotaLog.txt" # 移动云手机(n:normal)
    u_file="/data/local/tmp/portmap.json"       # 移动云手机极致版(u:ultimate)
    if [ -f "$n_file" ]; then
        $echo -e "脚本运行在移动云手机的云手机上" >>"$INPUT_LOG"
        get_n_com
    elif [ -f "$u_file" ]; then
        $echo -e "脚本运行在移动云手机极致版的云手机上" >>"$INPUT_LOG"
        get_u_com
    fi
}

# 函数:移动云手机获取公网端口
get_n_com() {
    # 搜索最后一个包含"aport":10000的段落，并提取所需的值
    result=$($grep -oP '{"address":"[^"]+","aport":10000,"atype":1},"external":{"address":"\K[^"]+|(?<=,"aport":)\d+' "$n_file" | tail -2)
    $echo -e "result:\n$result\n" >>"$INPUT_LOG"
    n_external_address=$($echo "$result" | head -1) # 提取公网ip
    n_external_aport=$($echo "$result" | tail -1)   # 提取公网端口
    $echo -e "n_external_address:\n$n_external_address\nexternal_aport:\n$n_external_aport" >>"$INPUT_LOG"
    echo -e "云手机ip:\t$n_external_address\n内网端口:\t10000\t=====>\t公网端口:\t$n_external_aport\n内网端口:\t10001\t=====>\t公网端口:\t$((n_external_aport + 1))\n内网端口:\t10002\t=====>\t公网端口:\t$((n_external_aport + 2))\n内网端口:\t10003\t=====>\t公网端口:\t$((n_external_aport + 3))\n内网端口:\t10004\t=====>\t公网端口:\t$((n_external_aport + 4))" | tee "$SCRIPT_DIR/../端口映射关系.txt" | tee -a "$INPUT_LOG"
    echo -e "${green}更多端口映射关系已保存到 ${yellow}$(dirname "$SCRIPT_DIR")/端口映射关系.txt ${green}中${nc}"
    read -rp "按任意键退出"
    exit 0
}

# 函数:移动云手机极致版获取端口
get_u_com() {
    # 读取开放端口映射的公网端口及公网ip
    u_external_aport_10000=$($jq -r '.[] | select(.type=="10000") | .access_port' "$u_file")
    u_external_aport_10001=$($jq -r '.[] | select(.type=="10001") | .access_port' "$u_file")
    u_external_aport_10002=$($jq -r '.[] | select(.type=="10002") | .access_port' "$u_file")
    u_external_aport_10003=$($jq -r '.[] | select(.type=="10003") | .access_port' "$u_file")
    u_external_aport_10004=$($jq -r '.[] | select(.type=="10004") | .access_port' "$u_file")
    u_external_address=$($jq -r '.[] | select(.type=="10000") | .public_ip' "$u_file")
    show_u_com
}

# 函数:显示移动云手机极致版端口相关信息
show_u_com(){
    $echo -e "云手机ip:\t$u_external_address\n内网端口:\t10000\t=====>\t公网端口:\t$u_external_aport_10000\n内网端口:\t10001\t=====>\t公网端口:\t$u_external_aport_10001\n内网端口:\t10002\t=====>\t公网端口:\t$u_external_aport_10002\n内网端口:\t10003\t=====>\t公网端口:\t$u_external_aport_10003\n内网端口:\t10004\t=====>\t公网端口:\t$u_external_aport_10004" | tee "$SCRIPT_DIR/../端口映射关系.txt" | tee -a "$INPUT_LOG"
    $echo -e "${green}更多端口映射关系已保存到 ${yellow}$(dirname "$SCRIPT_DIR")/端口映射关系.txt ${green}中${nc}"
}
detect_method_get_external_com