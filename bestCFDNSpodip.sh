#!/bin/bash

CONFIG_FILE="$HOME/.cf_dnspod_config.yaml"
SCRIPT_PATH="$(realpath "$0")"

# 如果传入 --auto，则只负责安装 crontab，然后退出
if [ "$1" = "--auto" ]; then
  cron_entry="*/15 * * * * $SCRIPT_PATH"
  # 如果 crontab 中还没有这条，则追加
  ( crontab -l 2>/dev/null | grep -Fxq "$cron_entry" ) || \
    ( crontab -l 2>/dev/null; echo "$cron_entry" ) | crontab -
  echo "✅ 已将脚本添加到 crontab，每 15 分钟运行一次："
  echo "   $cron_entry"
  exit 0
fi

function print_rainbow() {
  # 定义一组 ANSI 彩虹色码（红、黄、绿、青、蓝、洋红）
  colors=(31 33 32 36 34 35)

  # 逐行读取 ASCII 艺术，然后逐字符输出，不断循环颜色
  while IFS= read -r line; do
    for ((j=0; j<${#line}; j++)); do
      # 计算当前字符的颜色索引
      color=${colors[$((j % ${#colors[@]}))]}
      # 打印带颜色的单个字符
      printf "\033[${color}m%s" "${line:j:1}"
    done
    # 换行并重置颜色
    printf "\033[0m\n"
done << 'EOF'
 ____                       __
/\  _`\                  __/\ \                     __
\ \ \L\ \  __  __  _ __ /\_\ \ \____  __  __  _ __ /\_\
 \ \  _ <'/\ \/\ \/\`'__\/\ \ \ '__`\/\ \/\ \/\`'__\/\ \
  \ \ \L\ \ \ \_\ \ \ \/ \ \ \ \L\ \ \ \_\ \ \ \/ \ \ \
   \ \____/\ \____/\ \_\  \ \_\ \_,__/\ \____/\ \_\  \ \_\
    \/___/  \/___/  \/_/   \/_/\/___/  \/___/  \/_/   \/_/

EOF
}

function load_config() {
  # 确保文件存在
  [ -f "$CONFIG_FILE" ] || return 1

  while IFS=: read -r key value; do
    # 跳过空行或注释
    [[ -z "$key" || "${key:0:1}" == "#" ]] && continue

    # 去掉 key 尾部空格
    key="${key%%[[:space:]]}"
    # 去掉 value 前导空格
    value="${value#"${value%%[![:space:]]*}"}"

    # 全局声明这个变量
    # Bash 4+ 支持 declare -g
    declare -g "${key}"="${value}"
  done < "$CONFIG_FILE"
}

function create_config() {
    # 提供CPU架构选择
    PS3='请选择你的CPU架构 (默认: Linux x86_64 64位): '
    options=(
        "Linux x86 32位"
        "Linux x86_64 64位"
        "Linux ARM v8 64位"
        "Linux ARM v5 32位"
        "Linux ARM v6 32位"
        "Linux ARM v7 32位"
        "Linux Mips 32位"
        "Linux Mips 64位"
        "Linux Mipsle 32位"
        "Linux Mipsle 64位"
    )

    # 交互式选择CPU架构
    echo "可选CPU架构："
    for i in "${!options[@]}"; do
      printf "  %d) %s\n" $((i+1)) "${options[i]}"
    done
    read -p "请输入CPU架构编号（默认: Linux x86_64 64位）: " choice
    choice=${choice:-2}
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#options[@]} )); then
      echo "无效输入，已使用默认CPU架构。"
      choice=2
    fi
    cpu_arch="${options[choice-1]}"
    echo "已选择CPU架构：$cpu_arch"

    # 交互式填写信息
    echo "密钥请前往官网控制台 https://console.cloud.tencent.com/cam/capi 进行获取"
    read -p "请输入腾讯云SecretId: " secret_id
    read -p "请输入腾讯云SecretKey: " secret_key
    read -p "请输入域名 (例如 example.com): " Domain
    read -p "请输入主机记录（例如 www，默认: @）: " SubDomain
    SubDomain=${SubDomain:-"@"}

    # 定义选项数组
    options=(默认 电信 联通 移动 教育网 海外 其他)
    # 打印选项
    echo "可选线路："
    for i in "${!options[@]}"; do
      printf "  %d) %s\n" $((i+1)) "${options[i]}"
    done
    # 读用户输入，提示中写上默认值 [1]
    read -p "请输入线路编号（默认: 1）: " choice
    # 回车或输入空串时，设为默认 1
    choice=${choice:-1}
    # 如果用户输入了非数字，或超出范围，则提示并改回默认
    if ! [[ "$choice" =~ ^[0-9]+$ ]] \
      || (( choice < 1 || choice > ${#options[@]} )); then
      echo "无效输入，已使用默认线路。"
      choice=1
    fi
    # 映射到选项文字
    RecordLine="${options[choice-1]}"
    echo "已选择线路：$RecordLine"

    # 写入配置到YAML
    cat > "$CONFIG_FILE" <<EOF
cpu_arch: $cpu_arch
secret_id: $secret_id
secret_key: $secret_key
Domain: $Domain
SubDomain: $SubDomain
RecordLine: $RecordLine
EOF
}

# 命令行参数处理
if [ "$1" == "--config" ]; then
    print_rainbow
    create_config
elif [ -f "$CONFIG_FILE" ]; then
    echo "检测到已有配置，正在加载配置..."
    load_config
else
    create_config
fi

# 获取CloudflareSpeedTest工具
CF_DIR="$HOME/CloudflareST"
CF_TOOL="$CF_DIR/CloudflareST"
CF_CSV="$CF_DIR/result.csv"

if [ ! -d "$CF_DIR" ]; then
    echo "[$(date '+%F %T')] ▶ 正在下载CloudflareSpeedTest工具…"
    mkdir "$CF_DIR" && cd "$CF_DIR"
    wget -N "https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.0/CloudflareST_linux_$cpu_arch.tar.gz" || \
    wget -N "https://ghfast.top/https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.0/CloudflareST_linux_$cpu_arch.tar.gz"
    tar -xzf "CloudflareST_linux_$cpu_arch.tar.gz"
    rm "CloudflareST_linux_$cpu_arch.tar.gz"
    chmod +x CloudflareST
else
    echo "[$(date '+%F %T')] ▶ CloudflareSpeedTest工具已存在，跳过下载。"
fi

# 测速并获取最快IP
cd "$CF_DIR"
echo "[$(date '+%F %T')] ▶ 测速中…"
"$CF_TOOL"
fastest_ip=$(awk -F, 'NR==2{print $1}' "$CF_CSV")
echo "[$(date '+%F %T')] ✅ 最佳IP: $fastest_ip"

# 查询当前RecordId
function tencent_api_request() {
    local action="$1"
    local payload="$2"

    local host="dnspod.tencentcloudapi.com"
    local algorithm="TC3-HMAC-SHA256"
    local timestamp=$(date +%s)
    local date=$(date -u -d @$timestamp +"%Y-%m-%d")
    local service="dnspod"

    local http_request_method="POST"
    local canonical_uri="/"
    local canonical_querystring=""
    local canonical_headers="content-type:application/json; charset=utf-8\nhost:$host\nx-tc-action:$(echo $action | awk '{print tolower($0)}')\n"
    local signed_headers="content-type;host;x-tc-action"
    local hashed_request_payload=$(echo -n "$payload" | openssl sha256 -hex | awk '{print $2}')

    local canonical_request="$http_request_method\n$canonical_uri\n$canonical_querystring\n$canonical_headers\n$signed_headers\n$hashed_request_payload"
    local credential_scope="$date/$service/tc3_request"
    local hashed_canonical_request=$(printf "$canonical_request" | openssl sha256 -hex | awk '{print $2}')
    local string_to_sign="$algorithm\n$timestamp\n$credential_scope\n$hashed_canonical_request"

    local secret_date=$(printf "$date" | openssl sha256 -hmac "TC3$secret_key" | awk '{print $2}')
    local secret_service=$(printf $service | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_date" | awk '{print $2}')
    local secret_signing=$(printf "tc3_request" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_service" | awk '{print $2}')
    local signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_signing" | awk '{print $2}')

    local authorization="$algorithm Credential=$secret_id/$credential_scope, SignedHeaders=$signed_headers, Signature=$signature"

    curl -s -XPOST "https://$host" -d "$payload" \
    -H "Authorization: $authorization" \
    -H "Content-Type: application/json; charset=utf-8" \
    -H "Host: $host" \
    -H "X-TC-Action: $action" \
    -H "X-TC-Timestamp: $timestamp" \
    -H "X-TC-Version: 2021-03-23"
}

query_payload="{\"Domain\":\"$Domain\"}"
echo "[$(date '+%F %T')] ▶ 查询DNS记录列表…"
response=$(tencent_api_request "DescribeRecordList" "$query_payload")
RecordId=$(echo "$response" | grep -oP '(?<="RecordId":)\d+(?=,[^}]*"Name":"'$SubDomain'")')

if [ -z "$RecordId" ]; then
    echo "[$(date '+%F %T')] ❌ 未找到指定的子域名记录，请确认子域名是否正确。"
    exit 1
else
    echo "[$(date '+%F %T')] ✅ 找到RecordId: $RecordId"
fi

# 更新DNS记录
update_payload="{\"Domain\":\"$Domain\",\"RecordType\":\"A\",\"RecordLine\":\"$RecordLine\",\"Value\":\"$fastest_ip\",\"RecordId\":$RecordId,\"SubDomain\":\"$SubDomain\"}"
echo "[$(date '+%F %T')] ▶ 更新DNS记录…"
update_response=$(tencent_api_request "ModifyRecord" "$update_payload")

if echo "$update_response" | grep -q "Error"; then
    echo "[$(date '+%F %T')] ❌ 更新DNS记录失败: $update_response"
else
    echo "[$(date '+%F %T')] ✅ DNS记录更新成功！"
    echo "[$(date '+%F %T')] ▶ 新的IP地址: $fastest_ip"
fi
