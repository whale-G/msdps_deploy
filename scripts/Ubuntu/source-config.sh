#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置国内源和Git加速脚本
set -e  # 遇到错误立即退出
echo -e "${GREEN}开始配置国内软件源和Git加速...${NC}"

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
    exit 1
fi

# 获取真实用户和主目录
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

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

# 配置Git使用HTTPS替换SSH
echo -e "${GREEN}配置Git使用HTTPS协议...${NC}"
cat > "$USER_HOME/.gitconfig" << EOF
[url "https://github.com/"]
        insteadOf = git@github.com:
EOF

# 修改.gitconfig的所有权
chown $REAL_USER:$REAL_USER "$USER_HOME/.gitconfig"

echo -e "${GREEN}apt国内源和Git加速配置完成！${NC}" 

# 配置阿里云容器镜像服务
echo -e "${GREEN}开始配置阿里云容器镜像服务...${NC}"

# 提示用户获取阿里云镜像信息
echo -e "${YELLOW}请按照以下步骤操作：${NC}"
echo -e "${YELLOW}1. 访问阿里云控制台 https://cr.console.aliyun.com/${NC}"
echo -e "${YELLOW}2. 点击左侧「镜像工具」-「镜像加速器」${NC}"
echo -e "${YELLOW}3. 在页面上可以找到您专属的加速器地址${NC}"

# 获取用户输入
read -p "请输入您的专属加速器地址 (形如 https://xxxxxx.mirror.aliyuncs.com): " ACCELERATOR_URL

# 创建 Docker 配置目录
mkdir -p /etc/docker

# 配置 Docker 使用阿里云镜像加速
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["${ACCELERATOR_URL}"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

# 重启 Docker 服务以应用新配置
echo -e "${GREEN}正在重启 Docker 服务...${NC}"
systemctl daemon-reload
systemctl restart docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}阿里云容器镜像服务配置成功！${NC}"
    echo -e "${GREEN}您现在可以使用加速器加速镜像拉取了${NC}"
else
    echo -e "${RED}Docker 服务重启失败，请检查配置是否正确${NC}"
    exit 1
fi

echo -e "${GREEN}下载配置完成，请继续执行部署脚本${NC}"    