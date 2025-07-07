#!/bin/sh

# 获取环境变量
SERVER_IP=${SERVER_IP:-localhost}
BACKEND_PORT=${BACKEND_PORT:-18000}
API_URL="http://$SERVER_IP:$BACKEND_PORT"

echo "Configuring API URL: $API_URL"

# 替换所有JS文件中的占位符
find /usr/share/nginx/html -type f -name "*.js" -exec sed -i "s|VITE_API_BASE_URL_PLACEHOLDER|$API_URL|g" {} +

echo "API URL configuration complete!"