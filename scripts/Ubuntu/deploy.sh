#!/bin/bash

# Web项目一键部署脚本
set -e  # 遇到错误立即退出

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 项目配置
CONFIG_DIR="../../configs"          # 定义配置文件路径
PROJECT_DIR="msdps_deploy"
FRONTEND_REPO="https://github.com/whale-G/msdps_vue.git"
BACKEND_REPO="https://github.com/whale-G/msdps.git"
FRONTEND_DIR="$PROJECT_DIR/frontend"
BACKEND_DIR="$PROJECT_DIR/backend"

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
    exit 1
fi

echo -e "${GREEN}开始部署Web项目...${NC}"

# 步骤1: 安装Docker和Docker Compose
echo -e "${GREEN}步骤1: 安装Docker和Docker Compose${NC}"
if ! command -v docker &> /dev/null; then
    echo "安装Docker..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    # 添加Docker官方GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    # 添加Docker官方APT仓库
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    # 更新包索引并安装Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    # 启用并启动Docker服务
    systemctl enable docker
    systemctl start docker
    echo "Docker安装完成"
else
    echo "Docker已安装，跳过安装步骤"
fi

if ! command -v docker-compose &> /dev/null; then
    echo "安装Docker Compose..."
    # 下载指定版本的Docker Compose二进制文件
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    # 添加执行权限
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose安装完成"
else
    echo "Docker Compose已安装，跳过安装步骤"
fi

# 配置Docker国内镜像源
echo -e "${GREEN}配置Docker国内镜像源...${NC}"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://registry.docker-cn.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF

# 重启Docker服务
echo -e "${GREEN}重启Docker服务...${NC}"
systemctl daemon-reload
systemctl restart docker

# 步骤2: 创建项目目录
echo -e "${GREEN}步骤2: 创建项目目录${NC}"
mkdir -p $PROJECT_DIR/{frontend,backend,mysql,redis}
cd $PROJECT_DIR

# 步骤3: 克隆前端和后端代码
echo -e "${GREEN}步骤3: 克隆前端和后端代码${NC}"
if [ ! -d "$FRONTEND_DIR/.git" ]; then
    echo "克隆前端项目..."
    git clone $FRONTEND_REPO $FRONTEND_DIR
else
    echo "前端项目已存在，拉取最新代码..."
    cd $FRONTEND_DIR
    git pull
    cd ..
fi

if [ ! -d "$BACKEND_DIR/.git" ]; then
    echo "克隆后端项目..."
    git clone $BACKEND_REPO $BACKEND_DIR
else
    echo "后端项目已存在，拉取最新代码..."
    cd $BACKEND_DIR
    git pull
    cd ..  
fi

# 步骤4: 创建配置文件
echo -e "${GREEN}步骤4: 创建配置文件${NC}"

# 创建web项目docker-compose文件
echo "开始创建web项目docker-compose文件..."
cp $CONFIG_DIR/docker-compose.yml docker-compose.yml

# 创建MySQL初始化脚本
echo "开始创建MySQL初始化脚本..."
cp $CONFIG_DIR/mysql/init.sql mysql/init.sql

# 创建Redis配置
echo "开始创建Redis初始化脚本..."
cp $CONFIG_DIR/redis/redis.conf redis/redis.conf

# 创建前端Dockerfile和Nginx配置
echo "创建前端项目Docerfile文件..."
cp $CONFIG_DIR/frontend/Dockerfile frontend/Dockerfile
cp $CONFIG_DIR/frontend/nginx.conf frontend/nginx.con

# 创建后端Dockerfile
echo "创建后端Dockerfile文件..."
cp $CONFIG_DIR/backend/Dockerfile backend/Dockerfile

# 步骤5: 配置环境变量
echo -e "${GREEN}步骤5: 配置环境变量${NC}"
if [ ! -f ".env" ]; then
    echo "请设置部署所需的环境变量:"
    read -p "MySQL root密码: " MYSQL_ROOT_PASSWORD
    read -p "MySQL数据库名: " MYSQL_DATABASE
    read -p "MySQL用户名: " MYSQL_USER
    read -p "MySQL密码: " MYSQL_PASSWORD
    read -p "Redis密码: " REDIS_PASSWORD
    read -p "Django超级用户名: " DJANGO_SUPERUSER_USERNAME
    read -p "Django超级用户密码: " DJANGO_SUPERUSER_PASSWORD

    cat > .env << EOF
# MySQL配置
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

# Redis配置
REDIS_PASSWORD=$REDIS_PASSWORD

# Django配置
DJANGO_SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=*
DJANGO_SUPERUSER_USERNAME=$DJANGO_SUPERUSER_USERNAME
DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD
EOF
else
    echo ".env文件已存在，使用现有配置"
fi

# 步骤6: 构建并启动容器
echo -e "${GREEN}步骤6: 构建并启动容器${NC}"
docker-compose up -d --build

# 等待服务启动
echo -e "${GREEN}等待服务启动...不要停止脚本${NC}"
sleep 30

# 显示容器状态
echo -e "${GREEN}当前容器状态：${NC}"
docker-compose ps

# 检查容器是否正常运行

echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}前端应用可通过 http://服务器IP 访问${NC}"
echo -e "${GREEN}Django管理后台可通过 http://服务器IP/admin 访问${NC}"
echo -e "${GREEN}管理员账号: $DJANGO_SUPERUSER_USERNAME${NC}"
echo -e "${GREEN}管理员密码: $DJANGO_SUPERUSER_PASSWORD${NC}"