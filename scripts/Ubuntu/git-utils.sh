#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 克隆代码的函数，带重试机制
clone_with_retry() {
    local repo_url=$1
    local target_dir=$2
    local repo_name=$(basename "$target_dir")
    local max_attempts=3
    local attempt=1
    local wait_time=5

    while true; do
        echo -e "${GREEN}尝试克隆 ${repo_name}（第 ${attempt} 次尝试）...${NC}"
        
        # 检查目录是否存在
        if [ -d "$target_dir" ]; then
            echo -e "${YELLOW}警告: 目标目录 ${target_dir} 已存在${NC}"
            read -p "是否继续克隆？这可能会覆盖现有文件 (Y/n): " continue_clone
            if [[ $continue_clone =~ ^[Nn]$ ]]; then
                echo -e "${RED}用户取消操作${NC}"
                exit 1
            fi
        fi

        # 直接克隆最新代码
        if git clone "$repo_url" "$target_dir" 2>/tmp/git_error; then
            echo -e "${GREEN}✓ ${repo_name} 克隆成功${NC}"
            return 0
        fi

        # 显示错误信息
        echo -e "${RED}操作失败: $(cat /tmp/git_error)${NC}"
        
        # 询问用户是否重试
        read -p "是否重试？(Y/n): " retry
        if [[ $retry =~ ^[Nn]$ ]]; then
            echo -e "${RED}用户取消操作${NC}"
            exit 1
        fi
        
        echo "等待 ${wait_time} 秒后重试..."
        sleep $wait_time
        
        # 增加等待时间，但不超过30秒
        wait_time=$((wait_time + 5))
        if [ $wait_time -gt 30 ]; then
            wait_time=30
        fi
        
        attempt=$((attempt + 1))
    done
}

# 导出主函数
export -f clone_with_retry