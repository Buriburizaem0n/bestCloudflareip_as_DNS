#!/bin/bash

CONFIG_FILE="$HOME/.cf_dnspod_config.yaml"
SCRIPT_PATH="$(realpath "$0")"

# 如果传入 --auto，则只负责安装 crontab，然后退出
if [ "$1" = "--auto" ]; then
  cron_entry="*/15 * * * * $SCRIPT_PATH"
  ( crontab -l 2>/dev/null | grep -Fxq "$cron_entry" ) || \
    ( crontab -l 2>/dev/null; echo "$cron_entry" ) | crontab -
  echo "✅ 已将脚本添加到 crontab，每 15 分钟运行一次："
  echo "   $cron_entry"
  exit 0
fi

# 用于检测并自动更新 CloudflareSpeedTest 工具
GITHUB_API="https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest"
function check_update_cf_tool() {
  local version_file="$CF_DIR/VERSION"
  # 获取最新版本号
  latest_version=$(curl -s "$GITHUB_API" | grep '"tag_name":' | sed -E 's/.*"([^\"]+)".*/\1/')
  # 读取本地版本号
  if [ -f "$version_file" ]; then
    local_version=$(<"$version_file")
  else
    local_version=""
  fi
  # 比较版本
  if [ "$latest_version" != "$local_version" ]; then
    echo "[$(date '+%F %T')] ▶ 检测到 CloudflareSpeedTest 新版本: $latest_version，正在更新…"
    # 下载并解压最新版本
    tarball="CloudflareST_linux_${cpu_arch}.tar.gz"
    download_url="https://github.com/XIU2/CloudflareSpeedTest/releases/download/${latest_version}/${tarball}"
    (wget -q -N "$download_url" -P "$CF_DIR") || \
      wget -q -N "https://ghfast.top/$download_url" -P "$CF_DIR"
    tar -xzf "$CF_DIR/$tarball" -C "$CF_DIR"
    chmod +x "$CF_DIR/CloudflareST"
    rm -f "$CF_DIR/$tarball"
    echo "$latest_version" > "$version_file"
    echo "[$(date '+%F %T')] ✅ 更新完成"
  else
    echo "[$(date '+%F %T')] ➡️ CloudflareSpeedTest 已是最新版本: $local_version"
  fi
}

function print_rainbow() {
  colors=(31 33 32 36 34 35)
  while IFS= read -r line; do
    for ((j=0; j<${#line}; j++)); do
      color=${colors[$((j % ${#colors[@]}))]}
      printf "\033[${color}m%s" "${line:j:1}"
    done
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
  [ -f "$CONFIG_FILE" ] || return 1
  while IFS=: read -r key value; do
    [[ -z "$key" || "${key:0:1}" == "#" ]] && continue
    key="${key%%[[:space:]]}"
    value="${value#"${value%%[![:space:]]*}"}"
    declare -g "${key}"="${value}"
  done < "$CONFIG_FILE"
}

function create_config() {
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
    echo "可选CPU架构："
    for i in "${!options[@]}"; do
      printf "  %d) %s\n" $((i+1)) "${options[i]}"
    done
    read -p "请输入CPU架构编号（默认: 2）: " choice
    choice=${choice:-2}
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#options[@]} )); then
      echo "无效输入，已使用默认CPU架构。"
      choice=2
    fi
    cpu_arch="${options[choice-1]}"
    echo "已选择CPU架构：$cpu_arch"

    read -p "请输入腾讯云SecretId: " secret_id
    read -p "请输入腾讯云SecretKey: " secret_key
    read -p "请输入域名 (例如 example.com): " Domain
    read -p "请输入主机记录（默认: @）: " SubDomain
    SubDomain=${SubDomain:-"@"}

    options=(默认 电信 联通 移动 教育网 海外 其他)
    echo "可选线路："
    for i in "${!options[@]}"; do
      printf "  %d) %s\n" $((i+1)) "${options[i]}"
    done
    read -p "请输入线路编号（默认: 1）: " choice
    choice=${choice:-1}
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#options[@]} )); then
      echo "无效输入，已使用默认线路。"
      choice=1
    fi
    RecordLine="${options[choice-1]}"
    echo "已选择线路：$RecordLine"

    cat > "$CONFIG_FILE" <<EOF
cpu_arch: $cpu_arch
secret_id: $secret_id
secret_key: $secret_key
Domain: $Domain
SubDomain: $SubDomain
RecordLine: $RecordLine
EOF
}

# 参数处理
if [ "$1" == "--config" ]; then
    print_rainbow
    create_config
elif [ -f "$CONFIG_FILE" ]; then
    echo "检测到已有配置，正在加载配置..."
    load_config
else
    create_config
fi

# 设置工具目录并检查/更新 CloudflareSpeedTest
CF_DIR="$HOME/CloudflareST"
CF_TOOL="$CF_DIR/CloudflareST"
CF_CSV="$CF_DIR/result.csv"
mkdir -p "$CF_DIR"
cd "$CF_DIR"
check_update_cf_tool

# 运行测速并更新记录
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
