#!/bin/bash

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 使用后端镜像生成 Django SECRET_KEY
generate_django_secret_key() {
    local env_file=$1
    local backend_image=$2
    local project_dir=$3  # 新增：项目根目录参数
    
    if [ -z "$project_dir" ]; then
        echo -e "${RED}错误: 未提供项目根目录路径${NC}"
        return 1
    fi
    
    if [ ! -d "$project_dir/backend" ]; then
        echo -e "${RED}错误: 后端目录不存在: $project_dir/backend${NC}"
        return 1
    fi
    
    echo -e "${GREEN}生成Django SECRET_KEY...${NC}"
    
    # 使用后端镜像创建临时容器并生成 SECRET_KEY
    local NEW_SECRET_KEY=$(docker run --rm \
        -v "$project_dir/backend:/app" \
        -w /app \
        $backend_image \
        python -c '
from django.core.management.utils import get_random_secret_key
print(get_random_secret_key())
')

    if [ -n "$NEW_SECRET_KEY" ]; then
        # 更新环境变量文件中的SECRET_KEY
        if grep -q "SECRET_KEY=" "$env_file"; then
            # 如果存在SECRET_KEY行，则替换它
            sed -i "s|SECRET_KEY=.*|SECRET_KEY=$NEW_SECRET_KEY|" "$env_file"
        else
            # 如果不存在，则添加新行
            echo "SECRET_KEY=$NEW_SECRET_KEY" >> "$env_file"
        fi
        echo -e "${GREEN}SECRET_KEY已更新${NC}"
        return 0
    else
        echo -e "${RED}警告: SECRET_KEY生成失败${NC}"
        return 1
    fi
}

# 导出函数
export -f generate_django_secret_key 