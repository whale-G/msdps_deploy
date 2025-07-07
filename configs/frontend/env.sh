#!/bin/sh

# 获取环境变量
SERVER_IP=${SERVER_IP:-localhost}
BACKEND_PORT=${BACKEND_PORT:-18000}
API_URL="http://$SERVER_IP:$BACKEND_PORT"

echo "Configuring API URL: $API_URL"

# 替换运行时配置
find /usr/share/nginx/html -type f -name "index.html" -exec sed -i "s|VITE_API_BASE_URL: ''|VITE_API_BASE_URL: '$API_URL'|g" {} +

echo "API URL configuration complete!"