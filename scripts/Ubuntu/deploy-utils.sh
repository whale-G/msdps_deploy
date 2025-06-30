#!/bin/bash
# 部署工具函数脚本

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取服务器IP地址
# 该函数通过多种方法尝试获取服务器的可访问IP地址
# 返回值：
#   - 成功时返回服务器IP地址
#   - 失败时返回空字符串
get_server_ip() {
    # 首选获取默认路由接口的IP（通常是主要的外部接口）
    local ip=$(ip -4 route get 8.8.8.8 2>/dev/null | head -1 | awk '{print $7}')
    
    # 如果上述方法失败，尝试获取第一个非本地IP
    if [ -z "$ip" ]; then
        echo -e "${YELLOW}无法获取默认路由IP，尝试获取非本地IP...${NC}" >&2
        ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
    fi
    
    # 如果还是获取不到，使用hostname -I的第一个IP
    if [ -z "$ip" ]; then
        echo -e "${YELLOW}无法获取非本地IP，尝试使用hostname命令...${NC}" >&2
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    # 如果所有方法都失败了，输出错误信息
    if [ -z "$ip" ]; then
        echo -e "${RED}错误：无法获取服务器IP地址${NC}" >&2
        return 1
    fi
    
    echo "$ip"
}

# 导出函数
export -f get_server_ip