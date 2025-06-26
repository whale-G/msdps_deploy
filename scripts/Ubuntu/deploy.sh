#!/bin/bash

# Web项目一键部署脚本

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 项目配置
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

# 步骤3: 构建docker-compose文件
DOCKER_COMPOSE_FILE = "../../docker-compose.yml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "docker-compose文件不存在"
    echo "部署暂停，请确保部署文件完整..."
    exit 1
else
    echo "docker-compose文件已存在，可直接使用"
    mv $DOCKER_COMPOSE_FILE $PROJECT_DIR
fi

cd $PROJECT_DIR

# 步骤4: 克隆前端和后端代码
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

# 步骤5: 创建配置文件
echo -e "${GREEN}步骤4: 创建配置文件${NC}"

# 创建MySQL初始化脚本
echo "开始创建MySQL初始化脚本..."
cat > mysql/init.sql << EOF
-- 创建应用数据库
CREATE DATABASE IF NOT EXISTS \$MYSQL_DATABASE;

-- 创建用户并授权
CREATE USER IF NOT EXISTS '\$MYSQL_USER'@'%' IDENTIFIED BY '\$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \$MYSQL_DATABASE.* TO '\$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
EOF

# 创建Redis配置
echo "开始创建Redis初始化脚本..."
cat > redis/redis.conf << EOF
# 基础设置
bind 0.0.0.0              # 绑定所有接口，容器环境必需
protected-mode no         # 关闭保护模式，容器环境通常需要
port 6379                 # 监听端口
timeout 0                 # 客户端超时时间

# 持久化设置
save 900 1                # 900秒内至少1个key被修改则进行快照
save 300 10               # 300秒内至少10个key被修改则进行快照
save 60 10000             # 60秒内至少10000个key被修改则进行快照
appendonly yes            # 启用AOF持久化
appendfsync everysec      # AOF同步策略，每秒一次

# 内存管理
maxmemory 256mb               # 最大内存限制
maxmemory-policy allkeys-lru  # 内存不足时的淘汰策略

# 安全设置
requirepass \$REDIS_PASSWORD  # 设置访问密码
rename-command FLUSHALL ""    # 禁用危险命令
rename-command FLUSHDB ""     # 禁用危险命令

# 日志设置
loglevel notice             # 日志级别
logfile /var/log/redis.log  # 日志文件位置
EOF

# 创建前端Dockerfile
echo "创建前端项目Docerfile文件..."
cat > frontend/Dockerfile << EOF
FROM node:16 as build     # 使用Node.js 16作为构建环境

WORKDIR /app              # 设置工作目录

COPY package*.json ./     # 复制package.json文件
RUN npm install           # 安装依赖

COPY . .                  # 复制项目所有文件
RUN npm run build         # 执行Vue项目构建命令，生成dist目录

FROM nginx:1.21           # 使用Nginx作为运行环境

COPY --from=build /app/dist /usr/share/nginx/html     # 复制构建产物到Nginx目录
COPY nginx.conf /etc/nginx/conf.d/default.conf        # 复制Nginx配置

EXPOSE 80                 # 暴露端口80

CMD ["nginx", "-g", "daemon off;"]      # 启动Nginx
EOF

# 创建前端Nginx配置
echo "创建前端Nginx配置文件..."
cat > frontend/nginx.conf << EOF
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;             # 静态文件根目录
        index index.html;                       # 默认首页
        try_files \$uri \$uri/ /index.html;     # 处理Vue路由（单页应用）
    }

    location /gc_dt/ {
        proxy_pass http://backend:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
        add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization';
    }
}
EOF

# 创建后端Dockerfile
echo "创建后端Dockerfile文件..."
cat > backend/Dockerfile << EOF
FROM python:3.9

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

RUN pip install wait-for-it

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
EOF

# 步骤6: 配置环境变量
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
    read -p "Django超级用户邮箱: " DJANGO_SUPERUSER_EMAIL

    cat > .env << EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
DJANGO_SUPERUSER_USERNAME=$DJANGO_SUPERUSER_USERNAME
DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD
DJANGO_SUPERUSER_EMAIL=$DJANGO_SUPERUSER_EMAIL
EOF
else
    echo ".env文件已存在，使用现有配置"
fi

# 步骤7: 构建并启动容器
echo -e "${GREEN}步骤6: 构建并启动容器${NC}"
docker-compose up -d --build

echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}前端应用可通过 http://服务器IP 访问${NC}"
echo -e "${GREEN}Django管理后台可通过 http://服务器IP/admin 访问${NC}"
echo -e "${GREEN}管理员账号: $DJANGO_SUPERUSER_USERNAME${NC}"
echo -e "${GREEN}管理员密码: $DJANGO_SUPERUSER_PASSWORD${NC}"