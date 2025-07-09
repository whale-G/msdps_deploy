#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 分隔线函数
print_separator() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
}

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 错误: 请使用root权限运行此脚本${NC}"
    exit 1
fi

print_separator
echo -e "${BOLD}🚀 欢迎使用小西数据员Web项目部署脚本${NC}\n"

# 显示部署选项
echo -e "${CYAN}📝 请选择部署方式:${NC}"
echo -e "  1) 从阿里云镜像仓库拉取镜像（推荐）"
echo -e "  2) 本地构建镜像"

while true; do
    read -p "💡 请输入选项 (1/2): " deploy_choice
    case $deploy_choice in
        1)
            echo -e "${GREEN}🚀 选择从阿里云镜像仓库拉取镜像...${NC}"
            if [ -f "$SCRIPT_DIR/deploy-remote.sh" ]; then
                bash "$SCRIPT_DIR/deploy-remote.sh"
                exit $?
            else
                echo -e "${RED}❌ 错误: deploy-remote.sh 脚本不存在${NC}"
                exit 1
            fi
            ;;
        2)
            echo -e "${GREEN}🏗️ 选择本地构建镜像...${NC}"
            if [ -f "$SCRIPT_DIR/deploy-local.sh" ]; then
                bash "$SCRIPT_DIR/deploy-local.sh"
                exit $?
            else
                echo -e "${RED}❌ 错误: deploy-local.sh 脚本不存在${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}❌ 无效的选项，请重新输入${NC}"
            ;;
    esac
done
