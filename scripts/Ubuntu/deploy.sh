#!/bin/bash
# Web项目一键部署脚本

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
# 配置文件目录
CONFIG_DIR="$(realpath "$SCRIPT_DIR/../../configs")"

# 引入工具脚本
source "$SCRIPT_DIR/docker-utils.sh"
source "$SCRIPT_DIR/git-utils.sh"
source "$SCRIPT_DIR/django-utils.sh"

# 遇到错误立即退出
set -e  

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始部署Web项目...${NC}"

# 获取真实用户和主目录
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
PROJECT_DIR="$USER_HOME/msdps_web"
# 项目配置
CONFIG_DIR="../../configs"          # 定义配置文件路径
# 项目Gitee仓库
FRONTEND_REPO="https://github.com/whale-G/msdps_vue.git"
BACKEND_REPO="https://github.com/whale-G/msdps.git"
FRONTEND_DIR="$PROJECT_DIR/frontend"
BACKEND_DIR="$PROJECT_DIR/backend"

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
    exit 1
fi

# 步骤1: 安装Docker和Docker Compose
echo -e "${GREEN}步骤1: 配置Docker环境${NC}"
setup_docker_environment

# 如果Docker环境配置失败，退出脚本
if [ $? -ne 0 ]; then
    echo -e "${RED}Docker环境配置失败，部署终止${NC}"
    exit 1
fi

# 步骤2: 创建项目目录
echo -e "${GREEN}步骤2: 创建项目目录${NC}"
mkdir -p $PROJECT_DIR/{frontend,backend,mysql,redis,configs/env}
chown -R $REAL_USER:$REAL_USER $PROJECT_DIR
cd $PROJECT_DIR

# 步骤3: 克隆前端和后端代码
echo -e "${GREEN}步骤3: 克隆前端和后端代码${NC}"

# 克隆前端仓库
echo -e "${GREEN}克隆前端仓库...${NC}"
clone_with_retry "$FRONTEND_REPO" "$FRONTEND_DIR"
clone_frontend_status=$?

# 如果用户选择不覆盖现有目录，继续使用现有代码
if [ $clone_frontend_status -eq 2 ]; then
    echo -e "${YELLOW}使用现有前端代码继续部署${NC}"
fi

# 克隆后端仓库
echo -e "${GREEN}克隆后端仓库...${NC}"
clone_with_retry "$BACKEND_REPO" "$BACKEND_DIR"
clone_backend_status=$?

# 如果用户选择不覆盖现有目录，继续使用现有代码
if [ $clone_backend_status -eq 2 ]; then
    echo -e "${YELLOW}使用现有后端代码继续部署${NC}"
fi

# 步骤4: 创建配置文件
echo -e "${GREEN}步骤4: 创建配置文件${NC}"
cd $SCRIPT_DIR

# 创建web项目docker-compose相关文件
echo "开始创建web项目docker-compose相关文件..."
cp $CONFIG_DIR/docker-compose.yml "$PROJECT_DIR/docker-compose.yml"
touch "$PROJECT_DIR/docker-compose.env"

# 创建MySQL初始化脚本
echo "开始创建MySQL初始化脚本..."
cp $CONFIG_DIR/mysql/init.sql "$PROJECT_DIR/mysql/init.sql"

# 创建Redis配置
echo "开始创建Redis初始化脚本..."
cp $CONFIG_DIR/redis/redis.conf "$PROJECT_DIR/redis/redis.conf"

# 创建前端Dockerfile和Nginx配置
echo "创建前端项目Docerfile文件..."
cp $CONFIG_DIR/frontend/Dockerfile "$PROJECT_DIR/frontend/Dockerfile"
cp $CONFIG_DIR/frontend/nginx.conf "$PROJECT_DIR/frontend/nginx.conf"

# 创建后端Dockerfile和entrypoint.sh
echo "创建后端Dockerfile文件..."
cp $CONFIG_DIR/backend/Dockerfile "$PROJECT_DIR/backend/Dockerfile"
cp $CONFIG_DIR/backend/entrypoint.sh "$PROJECT_DIR/backend/entrypoint.sh"
chmod +x "$PROJECT_DIR/backend/entrypoint.sh"

# 步骤5: 配置web项目环境变量
echo -e "${GREEN}步骤5: 配置web项目环境变量${NC}"
if [ ! -f "$PROJECT_DIR/configs/env/.env" ] || [ ! -f "$PROJECT_DIR/configs/env/.env.production" ]; then
    echo "请设置部署所需的环境变量:"
    read -p "MySQLroot密码: root用户的管理员密码, 用于数据库的高级管理操作: " MYSQL_ROOT_PASSWORD
    read -p "MySQL数据库名: " MYSQL_DATABASE
    read -p "MySQL用户名: " MYSQL_USER
    read -p "MySQL密码: " MYSQL_PASSWORD
    read -p "Redis密码: " REDIS_PASSWORD
    read -p "Django管理员用户名: " DJANGO_SUPERUSER_USERNAME
    read -p "Django管理员初始密码: " DJANGO_SUPERUSER_PASSWORD
    echo

    # 创建配置文件
    mkdir -p $PROJECT_DIR/configs/env
    cp "$CONFIG_DIR/env/.env" "$PROJECT_DIR/configs/env/.env"

    # 创建初始环境变量文件，SECRET_KEY先用占位符
    cat > "$PROJECT_DIR/configs/env/.env.production" << EOF
# MySQL配置
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

# Redis配置
REDIS_PASSWORD=$REDIS_PASSWORD

# Django配置
DJANGO_SECRET_KEY=temp_secret_key_will_be_replaced
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=*
DJANGO_SUPERUSER_USERNAME=$DJANGO_SUPERUSER_USERNAME
DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD
EOF
else
    echo ".env文件已存在，使用现有配置"
fi

# 步骤6: 配置docker容器端口映射
echo -e "${GREEN}步骤6: 配置docker容器端口映射${NC}"

# 检查端口是否被占用的函数
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 1
    fi
    return 0
}

# 配置后端端口
while true; do
    read -p "后端服务端口 (默认: 18000): " BACKEND_PORT
    BACKEND_PORT=${BACKEND_PORT:-18000}  # 设置默认值
    
    if ! [[ "$BACKEND_PORT" =~ ^[0-9]+$ ]]; then
        echo "错误: 端口必须是数字"
        continue
    fi
    
    if [ "$BACKEND_PORT" -lt 1024 ] || [ "$BACKEND_PORT" -gt 65535 ]; then
        echo "错误: 端口必须在1024-65535之间"
        continue
    fi
    
    break
done

# 配置前端端口
while true; do
    read -p "前端服务端口 (默认: 18080): " FRONTEND_PORT
    FRONTEND_PORT=${FRONTEND_PORT:-18080}  # 修改默认值为更常用的18080
    
    if ! [[ "$FRONTEND_PORT" =~ ^[0-9]+$ ]]; then
        echo "错误: 端口必须是数字"
        continue
    fi
    
    if [ "$FRONTEND_PORT" -lt 1024 ] || [ "$FRONTEND_PORT" -gt 65535 ]; then
        echo "错误: 端口必须在1024-65535之间"
        continue
    fi
    
    if [ "$FRONTEND_PORT" -eq "$BACKEND_PORT" ]; then
        echo "错误: 前端端口不能与后端端口相同"
        continue
    fi
    
    break
done

# 检查端口冲突
echo -e "${GREEN}检查端口冲突...${NC}"
check_port_conflicts "$FRONTEND_PORT" "$BACKEND_PORT"

# 将端口信息写入docker-compose.env文件
echo "BACKEND_PORT=$BACKEND_PORT" > "$PROJECT_DIR/docker-compose.env"
echo "FRONTEND_PORT=$FRONTEND_PORT" >> "$PROJECT_DIR/docker-compose.env"

# 显示配置确认信息
echo -e "\n端口配置信息："
echo "后端服务端口: $BACKEND_PORT"
echo "前端服务端口: $FRONTEND_PORT"

# 步骤7: 构建并启动容器
echo -e "${GREEN}步骤7: 构建并启动容器${NC}"

# 构建所有镜像
echo -e "${GREEN}构建所有服务镜像...${NC}"
cd $PROJECT_DIR
if ! docker_compose_build_with_retry; then
    echo -e "${RED}镜像构建失败${NC}"
    exit 1
fi

# 使用构建好的后端镜像生成 SECRET_KEY
if ! generate_django_secret_key "$PROJECT_DIR/configs/env/.env.production" "msdps_web-backend" "$PROJECT_DIR"; then
    echo -e "${RED}SECRET_KEY生成失败，部署终止${NC}"
    exit 1
fi

# 启动所有容器
echo -e "${GREEN}开始启动所有容器...${NC}"
if ! docker_compose_up_with_retry; then
    echo -e "${RED}容器启动失败，请检查错误信息并重试${NC}"
    exit 1
fi

# 等待服务启动
echo -e "${GREEN}等待服务启动...不要停止脚本${NC}"
sleep 30

# 显示容器状态
echo -e "${GREEN}当前容器状态：${NC}"
docker compose ps

# 检查容器是否正常运行
echo -e "${GREEN}检查容器运行状态...${NC}"

# 定义需要检查的容器
CONTAINERS=("msdps_frontend" "msdps_backend" "msdps_mysql" "msdps_redis")

# 检查函数
check_container() {
    local container=$1
    # 检查容器是否存在且运行
    if [ "$(docker ps -q -f name=$container)" ]; then
        # 检查容器状态
        local status=$(docker inspect -f '{{.State.Status}}' $container)
        if [ "$status" = "running" ]; then
            echo -e "${GREEN}✓ $container 容器运行正常${NC}"
            return 0
        else
            echo -e "${RED}✗ $container 容器状态异常: $status${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ $container 容器不存在或未运行${NC}"
        return 1
    fi
}

# 检查所有容器
FAILED=0
for container in "${CONTAINERS[@]}"; do
    if ! check_container $container; then
        FAILED=1
    fi
done

# 如果有容器运行异常，显示日志并退出
if [ $FAILED -eq 1 ]; then
    echo -e "${RED}某些容器运行异常，显示详细日志：${NC}"
    for container in "${CONTAINERS[@]}"; do
        echo -e "\n${YELLOW}$container 容器日志：${NC}"
        docker logs $container
    done
    echo -e "${RED}部署失败：某些容器未能正常运行，请检查上述日志解决问题。${NC}"
    exit 1
else
    echo -e "${GREEN}所有容器运行正常！${NC}"
    echo -e "${GREEN}部署成功！您现在可以访问以下服务：${NC}"
    echo -e "${GREEN}前端应用可通过 http://服务器IP 访问${NC}"
    echo -e "${GREEN}Django管理后台可通过 http://服务器IP/admin 访问${NC}"
    echo -e "${GREEN}管理员账号: $DJANGO_SUPERUSER_USERNAME${NC}"
    echo -e "${GREEN}管理员密码: $DJANGO_SUPERUSER_PASSWORD${NC}"
fi