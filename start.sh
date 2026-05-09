#!/bin/bash

# 环境变量校验
if [ -z "$UUID" ]; then
  echo "ERROR: UUID environment variable is required"
  exit 1
fi

if [ -z "$ARGO_TOKEN" ]; then
  echo "ERROR: ARGO_TOKEN environment variable is required"
  exit 1
fi

WS_PATH="${WS_PATH:-vless}"

escape_sed() {
  printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'
}

# 替换配置文件中的 UUID 和 WS 路径
esc_uuid=$(escape_sed "$UUID")
esc_ws_path=$(escape_sed "$WS_PATH")
sed -i "s/PASTE_YOUR_UUID_HERE/$esc_uuid/g" config.json
sed -i "s/PASTE_YOUR_WS_PATH_HERE/$esc_ws_path/g" config.json

echo "Starting sing-box..."
sing-box run -c config.json &
SING_PID=$!

# 等待并验证 sing-box 是否启动成功
sleep 2
if ! kill -0 "$SING_PID" 2>/dev/null; then
  echo "ERROR: sing-box failed to start, checking logs:"
  sing-box run -c config.json 2>&1 || true
  exit 1
fi

# 检测端口是否就绪
for i in 1 2 3 4 5; do
  if (echo > /dev/tcp/127.0.0.1/8080) 2>/dev/null; then
    break
  fi
  if ! kill -0 "$SING_PID" 2>/dev/null; then
    echo "ERROR: sing-box process died during startup"
    exit 1
  fi
  sleep 1
done

if kill -0 "$SING_PID" 2>/dev/null; then
  echo "sing-box started successfully (PID: $SING_PID)"
else
  echo "ERROR: sing-box is not running"
  exit 1
fi

# 清理函数：任一进程退出时终止另一个
cleanup() {
  echo "Process exited, shutting down..."
  kill -TERM "$SING_PID" "$CF_PID" 2>/dev/null
  wait
}
trap cleanup EXIT TERM INT

echo "Starting cloudflared..."
cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" &
CF_PID=$!

# 等待任一进程退出
wait -n "$SING_PID" "$CF_PID"
echo "A process exited unexpectedly, stopping container..."
exit 1
