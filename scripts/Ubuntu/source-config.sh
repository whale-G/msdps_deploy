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

# 步骤提示函数
print_step() {
    local step=$1
    local total=$2
    local description=$3
    print_separator
    echo -e "${CYAN}【步骤 $step/$total】${BOLD}$description${NC}"
    print_separator
}

# 配置国内源和Git加速脚本
echo -e "\n${BOLD}🚀 开始执行环境配置脚本...${NC}\n"

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 错误: 请使用root权限运行此脚本${NC}"
    exit 1
fi

# 获取真实用户和主目录
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# 步骤1: 配置Ubuntu软件源
print_step 1 3 "配置Ubuntu软件源"
echo -e "${GREEN}📦 备份原始源列表...${NC}"
cp /etc/apt/sources.list /etc/apt/sources.list.bak

echo -e "${GREEN}📦 配置清华大学源...${NC}"
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

echo -e "${GREEN}📦 更新软件包索引...${NC}"
apt-get update

# 步骤2: 配置GitHub的hosts加速
print_step 2 3 "配置GitHub的hosts加速"
echo -e "${GREEN}🔄 备份hosts文件...${NC}"
cp /etc/hosts /etc/hosts.bak

echo -e "${GREEN}🔍 获取GitHub相关域名的IP地址...${NC}"
GITHUB_IP=$(nslookup github.com | grep -A1 'Name:' | grep 'Address:' | awk '{print $2}' | head -n 1)
GITHUB_FASTLY_IP=$(nslookup github.global.ssl.fastly.net | grep -A1 'Name:' | grep 'Address:' | awk '{print $2}' | head -n 1)

if [ -z "$GITHUB_IP" ] || [ -z "$GITHUB_FASTLY_IP" ]; then
    echo -e "${RED}❌ 获取GitHub IP地址失败，跳过hosts配置${NC}"
else
    echo -e "${GREEN}📝 添加GitHub相关的hosts配置...${NC}"
    echo -e "\n# GitHub加速配置" >> /etc/hosts
    echo "$GITHUB_FASTLY_IP github.global.ssl.fastly.net" >> /etc/hosts
    echo "$GITHUB_FASTLY_IP http://github.global.ssl.fastly.net" >> /etc/hosts
    echo "$GITHUB_FASTLY_IP https://github.global.ssl.fastly.net" >> /etc/hosts
    echo "$GITHUB_IP github.com" >> /etc/hosts
    echo "$GITHUB_IP http://github.com" >> /etc/hosts
    echo "$GITHUB_IP https://github.com" >> /etc/hosts

    echo -e "${GREEN}🔄 刷新DNS缓存...${NC}"
    
    echo -e "${GREEN}⚡ 重启systemd-resolved服务...${NC}"
    systemctl restart systemd-resolved

    if command -v nscd >/dev/null 2>&1; then
        echo -e "${GREEN}⚡ 重启nscd服务...${NC}"
        systemctl restart nscd || true
    fi

    if command -v systemd-resolve >/dev/null 2>&1; then
        echo -e "${GREEN}🧹 清除DNS缓存...${NC}"
        systemd-resolve --flush-caches
    fi

    echo -e "${GREEN}✅ GitHub hosts加速配置完成！${NC}"
fi

# 步骤3: 配置Docker镜像加速
print_step 3 3 "配置Docker镜像加速"

echo -e "${YELLOW}ℹ️  请按照以下步骤操作：${NC}"
echo -e "${YELLOW}1. 访问阿里云控制台 https://cr.console.aliyun.com/${NC}"
echo -e "${YELLOW}2. 点击左侧「镜像工具」-「镜像加速器」${NC}"
echo -e "${YELLOW}3. 在页面上可以找到您专属的加速器地址${NC}"

read -p "💡 请输入您的专属加速器地址 (形如 https://xxxxxx.mirror.aliyuncs.com): " ACCELERATOR_URL

echo -e "${GREEN}📁 创建Docker配置目录...${NC}"
mkdir -p /etc/docker

echo -e "${GREEN}📝 配置Docker镜像加速...${NC}"
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "${ACCELERATOR_URL}",
    "https://docker.m.daocloud.io"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

echo -e "${GREEN}🔄 重启Docker服务...${NC}"
systemctl daemon-reload
systemctl restart docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 阿里云容器镜像服务配置成功！${NC}"
    echo -e "${GREEN}✨ 您现在可以使用加速器加速镜像拉取了${NC}"
else
    echo -e "${RED}❌ Docker服务重启失败，请检查配置是否正确${NC}"
    exit 1
fi

print_separator
echo -e "${GREEN}✅ 所有配置完成！${NC}"
echo -e "${CYAN}📝 配置总结：${NC}"
echo -e "  ✓ Ubuntu软件源已更新为清华源"
echo -e "  ✓ GitHub访问已配置加速"
echo -e "  ✓ Docker镜像已配置加速"
print_separator
echo -e "\n${BOLD}🚀 请继续执行部署脚本（deploy.sh）...${NC}\n"