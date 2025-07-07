#!/bin/sh

# 获取环境变量，如果未设置则使用默认值
VITE_API_BASE_URL=${VITE_API_BASE_URL:-http://localhost:18000}

echo "Configuring frontend with API URL: ${VITE_API_BASE_URL}"

# 检查目标目录是否存在
if [ ! -d "/usr/share/nginx/html" ]; then
    echo "Error: /usr/share/nginx/html directory not found"
    exit 1
fi

# 查找并替换环境变量
echo "Searching for files to update..."
FOUND_FILES=$(find /usr/share/nginx/html -type f -name "*.js" -o -name "*.html" -o -name "*.css" 2>/dev/null)

if [ -z "$FOUND_FILES" ]; then
    echo "Warning: No files found to update"
    exit 0
fi

echo "Updating files with API URL..."
echo "$FOUND_FILES" | while read -r file; do
    if [ -f "$file" ]; then
        # 检查文件是否包含占位符
        if grep -q "VITE_API_BASE_URL_PLACEHOLDER" "$file"; then
            echo "Updating file: $file"
            sed -i "s|VITE_API_BASE_URL_PLACEHOLDER|${VITE_API_BASE_URL}|g" "$file"
        fi
    fi
done

echo "Configuration complete!"