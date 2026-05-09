#!/bin/sh

# 环境变量校验
if [ -z "$UUID" ]; then
  echo "ERROR: UUID environment variable is required"
  exit 1
fi

if [ -z "$ARGO_TOKEN" ]; then
  echo "ERROR: ARGO_TOKEN environment variable is required"
  exit 1
fi

WS_PATH="${WS_PATH:-/vless}"

escape_sed() {
  printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'
}

# 替换配置文件中的 UUID 和 WS 路径
esc_uuid=$(escape_sed "$UUID")
esc_ws_path=$(escape_sed "$WS_PATH")
sed -i "s/PASTE_YOUR_UUID_HERE/$esc_uuid/g" config.json
sed -i "s/PASTE_YOUR_WS_PATH_HERE/$esc_ws_path/g" config.json

# 清理函数：任一进程退出时终止另一个
cleanup() {
  echo "Process exited, shutting down..."
  kill -TERM "$SING_PID" "$CF_PID" 2>/dev/null
  wait
  exit 1
}

trap cleanup TERM INT

# 后台运行 sing-box
sing-box run -c config.json &
SING_PID=$!

# 运行 Cloudflare Tunnel（也放后台以便 wait -n 监听）
cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" &
CF_PID=$!

# 等待任一进程退出
wait -n "$SING_PID" "$CF_PID"
echo "A process exited unexpectedly, stopping container..."
cleanup
