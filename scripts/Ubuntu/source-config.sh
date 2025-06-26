#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 配置国内源和Git加速脚本
set -e  # 遇到错误立即退出
echo -e "${GREEN}开始配置国内软件源和Git加速...${NC}"

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
    exit 1
fi

# 备份原始源列表
echo -e "${GREEN}备份原始源列表...${NC}"
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 使用清华大学源替换默认源
echo -e "${GREEN}配置Ubuntu软件源为清华大学源...${NC}"
cat > /etc/apt/sources.list << EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
EOF

# 更新软件包索引
echo -e "${GREEN}更新软件包索引...${NC}"
apt-get update

# 配置Git使用国内镜像加速
echo -e "${GREEN}配置Git使用国内镜像加速...${NC}"
git config --global url."https://hub.fastgit.xyz".insteadOf "https://ghproxy.com/https://github.com".insteadOf "https://github.com"

echo -e "${GREEN}国内源和Git加速配置完成！${NC}"    