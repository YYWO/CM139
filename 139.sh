#!/system/bin/sh

# 开始监听 10000-10004 端口
for port in $(seq 10000 10004); do
  /data/adb/magisk/busybox nc -l -p $port >/dev/null &
  pid=$!
  echo "端口 $port 的进程PID为: $pid"
done

# 记录端口映射信息到文件
echo "--------------------------------" > //storage/emulated/0/Download//端口映射.txt

# 获取公网 IP 地址
ipv4_address=$(curl -s --max-time 5 ip.sb -4)
ipv6_address=$(curl -s --max-time 5 ip.sb -6)

# 记录 IP 地址到文件
[ -n "$ipv4_address" ] && echo "本机IPv4地址: $ipv4_address" >> //storage/emulated/0/Download//端口映射.txt
[ -n "$ipv6_address" ] && echo "本机IPv6地址: $ipv6_address" >> //storage/emulated/0/Download//端口映射.txt
echo "端口映射及占用情况: " >> //storage/emulated/0/Download//端口映射.txt

# 基于内网 IP 地址的最后一段，计算公网端口偏移量
mapped_port=$((10000 + ($(ifconfig wlan0 | grep 'inet ' | awk '{print $2}' | cut -d'.' -f4) - 2) * 5))

# 检查端口映射及占用情况，并添加公网端口映射
for i in $(seq 0 4); do 
    base_port=$((10000 + i))           # 内网端口
    actual_port=$((mapped_port + i))   # 公网端口（内网端口+映射偏移值）
    
    # 检查内网端口是否被占用
    process_info=$(netstat -tlnp 2>/dev/null | grep ":$base_port")
    process=$(echo "$process_info" | awk '{sub(/[0-9]+\//, "", $NF); print $NF; exit}')
    pid=$(echo "$process_info" | awk '{print $7}' | cut -d'/' -f1)

    if [ -n "$process" ]; then
        if [ "$process" = "busybox" ]; then
            echo "$base_port → 公网端口 $actual_port 未被占用" >> //storage/emulated/0/Download//端口映射.txt
            # 杀掉所有 busybox 进程
            echo "正在杀掉所有 busybox 进程..."
            killall busybox
        else
            echo "$base_port → 公网端口 $actual_port 被进程 $process 占用" >> //storage/emulated/0/Download//端口映射.txt
        fi
    else
        echo "$base_port → 公网端口 $actual_port 未被占用" >> //storage/emulated/0/Download//端口映射.txt
    fi
done

# 记录当前检测时间
echo "-------检-测-时-间-------" >> //storage/emulated/0/Download//端口映射.txt
date "+%Y-%m-%d %H:%M:%S" >> //storage/emulated/0/Download//端口映射.txt
