#!/bin/bash
# Web项目一键部署脚本

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

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
# 配置文件目录
CONFIG_DIR="$(realpath "$SCRIPT_DIR/../../configs")"

# 引入各工具脚本
echo -e "\n${BOLD}🚀 开始小西数据员Web项目部署...（使用远程镜像）${NC}\n"
echo -e "${GREEN}📚 加载工具脚本...${NC}"
# docker工具函数
source "$SCRIPT_DIR/docker-utils.sh"
# git工具函数
source "$SCRIPT_DIR/git-utils.sh"
# django工具函数
source "$SCRIPT_DIR/django-utils.sh"
# 部署工具函数
source "$SCRIPT_DIR/deploy-utils.sh"

# 获取服务器IP
SERVER_IP=$(get_server_ip)
echo -e "${GREEN}🌐 当前服务器IP: ${SERVER_IP}${NC}"

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 错误: 请使用root权限运行此脚本${NC}"
    exit 1
fi

# 获取真实用户和主目录
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
PROJECT_DIR="$USER_HOME/msdps_web"

# 项目配置
CONFIG_DIR="../../configs"          # 定义配置文件路径
FRONTEND_DIR="$PROJECT_DIR/frontend"
BACKEND_DIR="$PROJECT_DIR/backend"

# 步骤1: 安装Docker和Docker Compose
print_step 1 6 "配置Docker环境"
setup_docker_environment

# 如果Docker环境配置失败，退出脚本
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Docker环境配置失败，部署终止${NC}"
    exit 1
fi

# 步骤2: 创建项目目录
print_step 2 6 "创建项目目录"
echo -e "${GREEN}📁 创建项目必要的目录...${NC}"
if ! mkdir -p $PROJECT_DIR/{frontend,backend,mysql,redis,configs/env}; then
    echo -e "${RED}❌ 创建项目目录失败${NC}"
    exit 1
fi
if ! chown -R $REAL_USER:$REAL_USER $PROJECT_DIR; then
    echo -e "${RED}❌ 设置项目目录权限失败${NC}"
    exit 1
fi
cd $PROJECT_DIR || exit 1

# 步骤3: 配置docker容器端口映射
print_step 3 6 "配置服务端口"

# 配置后端端口
echo -e "${GREEN}🔧 配置后端服务端口...${NC}"
while true; do
    read -p "💡 后端服务端口 (默认: 18000): " BACKEND_PORT
    BACKEND_PORT=${BACKEND_PORT:-18000}
    
    if ! [[ "$BACKEND_PORT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ 错误: 端口必须是数字${NC}"
        continue
    fi
    
    if [ "$BACKEND_PORT" -lt 1024 ] || [ "$BACKEND_PORT" -gt 65535 ]; then
        echo -e "${RED}❌ 错误: 端口必须在1024-65535之间${NC}"
        continue
    fi
    
    break
done

# 配置前端端口
echo -e "${GREEN}🔧 配置前端服务端口...${NC}"
while true; do
    read -p "💡 前端服务端口 (默认: 18080): " FRONTEND_PORT
    FRONTEND_PORT=${FRONTEND_PORT:-18080}
    
    if ! [[ "$FRONTEND_PORT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ 错误: 端口必须是数字${NC}"
        continue
    fi
    
    if [ "$FRONTEND_PORT" -lt 1024 ] || [ "$FRONTEND_PORT" -gt 65535 ]; then
        echo -e "${RED}❌ 错误: 端口必须在1024-65535之间${NC}"
        continue
    fi
    
    if [ "$FRONTEND_PORT" -eq "$BACKEND_PORT" ]; then
        echo -e "${RED}❌ 错误: 前端端口不能与后端端口相同${NC}"
        continue
    fi
    
    break
done

# 检查端口冲突
echo -e "${GREEN}🔍 检查端口冲突...${NC}"
check_port_conflicts "$FRONTEND_PORT" "$BACKEND_PORT"

# 将 服务器IP 与 前后端容器端口 信息写入docker-compose.env文件
echo -e "${GREEN}📝 保存端口配置...${NC}"
if ! echo "BACKEND_PORT=$BACKEND_PORT" > "$PROJECT_DIR/docker-compose.env" || \
   ! echo "FRONTEND_PORT=$FRONTEND_PORT" >> "$PROJECT_DIR/docker-compose.env" || \
   ! echo "SERVER_IP=$SERVER_IP" >> "$PROJECT_DIR/docker-compose.env"; then
    echo -e "${RED}❌ 创建docker-compose.env文件失败${NC}"
    exit 1
fi

# 显示配置确认信息
echo -e "\n${CYAN}📋 端口配置信息：${NC}"
echo -e "  ⚡ 后端服务端口: $BACKEND_PORT"
echo -e "  ⚡ 前端服务端口: $FRONTEND_PORT"

# 步骤4: 创建配置文件
print_step 4 6 "创建配置文件"
cd $SCRIPT_DIR || exit 1

# 创建并设置MySQL数据目录权限
echo -e "${GREEN}📁 配置MySQL容器...${NC}"
if ! mkdir -p "$PROJECT_DIR/mysql/data"; then
    echo -e "${RED}❌ 创建MySQL容器数据目录失败${NC}"
    exit 1
fi
if ! chown -R 999:999 "$PROJECT_DIR/mysql/data"; then
    echo -e "${RED}❌ 设置MySQL数据目录权限失败${NC}"
    exit 1
fi
# 创建MySQL初始化脚本
if ! cp $CONFIG_DIR/mysql/init.sql "$PROJECT_DIR/mysql/init.sql"; then
    echo -e "${RED}❌ 创建MySQL容器初始化脚本失败${NC}"
    exit 1
fi

# 创建并设置Redis数据目录权限
echo -e "${GREEN}📁 配置Redis容器...${NC}"
if ! mkdir -p "$PROJECT_DIR/redis/data"; then
    echo -e "${RED}❌ 创建Redis容器数据目录失败${NC}"
    exit 1
fi
if ! chown -R 999:999 "$PROJECT_DIR/redis/data"; then
    echo -e "${RED}❌ 设置Redis容器数据目录权限失败${NC}"
    exit 1
fi
# 创建Redis配置
if ! cp $CONFIG_DIR/redis/redis.conf "$PROJECT_DIR/redis/redis.conf"; then
    echo -e "${RED}❌ 创建Redis容器配置文件失败${NC}"
    exit 1
fi

# 创建前端相关文件
echo -e "${GREEN}📁 配置前端容器...${NC}"
if ! cp $CONFIG_DIR/frontend/Dockerfile "$PROJECT_DIR/frontend/Dockerfile" || \
   ! cp $CONFIG_DIR/frontend/nginx.conf "$PROJECT_DIR/frontend/nginx.conf" || \
   ! cp $CONFIG_DIR/frontend/env.sh "$PROJECT_DIR/frontend/env.sh"; then
    echo -e "${RED}❌ 创建前端容器配置文件失败${NC}"
    exit 1
fi

# 创建后端相关文件和目录
echo -e "${GREEN}📁 配置后端容器...${NC}"
if ! cp $CONFIG_DIR/backend/Dockerfile "$PROJECT_DIR/backend/Dockerfile" || \
   ! cp $CONFIG_DIR/backend/entrypoint.sh "$PROJECT_DIR/backend/entrypoint.sh"; then
    echo -e "${RED}❌ 创建后端容器配置文件失败${NC}"
    exit 1
fi
if ! chmod +x "$PROJECT_DIR/backend/entrypoint.sh"; then
    echo -e "${RED}❌ 设置entrypoint.sh执行权限失败${NC}"
    exit 1
fi
if ! mkdir -p "$PROJECT_DIR/backend/logs" || ! mkdir -p "$PROJECT_DIR/backend/static"; then
    echo -e "${RED}❌ 创建后端容器日志和静态文件目录失败${NC}"
    exit 1
fi
if ! mkdir -p $PROJECT_DIR/configs/env; then
    echo -e "${RED}❌ 创建后端容器环境变量目录失败${NC}"
    exit 1
fi

# 复制和创建环境变量文件
if ! cp "$CONFIG_DIR/env/.env" "$PROJECT_DIR/configs/env/.env"; then
    echo -e "${RED}❌ 创建.env文件失败${NC}"
    exit 1
fi

# 步骤5: 配置web项目环境变量
print_step 5 6 "配置环境变量"

# 预设项目环境变量
MYSQL_ROOT_PASSWORD=123Abc456
MYSQL_DATABASE=msdps_db
MYSQL_USER=msdps_db_user
MYSQL_PASSWORD=123Abc456
REDIS_PASSWORD=123Abc456
DJANGO_ADMIN_ACCOUNT=admin
DJANGO_ADMIN_PASSWORD=123Abc456

# 创建MySQL环境变量文件
echo -e "${GREEN}📝 创建MySQL环境配置...${NC}"
cat > "$PROJECT_DIR/configs/env/mysql.env" << EOF
# MySQL配置
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOF

# 创建Redis环境变量文件
echo -e "${GREEN}📝 创建Redis环境配置...${NC}"
cat > "$PROJECT_DIR/configs/env/redis.env" << EOF
# Redis配置
REDIS_PASSWORD=$REDIS_PASSWORD
EOF

# 更新Redis配置文件中的密码
if ! sed -i "s/requirepass .*/requirepass $REDIS_PASSWORD/" "$PROJECT_DIR/redis/redis.conf"; then
    echo -e "${RED}❌ 更新Redis配置文件失败${NC}"
    exit 1
fi

# 创建Django生产环境配置文件
echo -e "${GREEN}📝 创建Django环境配置...${NC}"
cat > "$PROJECT_DIR/configs/env/.env.production" << EOF
# 基础配置
DJANGO_ENV=production
DEBUG=False
ALLOWED_HOSTS=*

# CORS跨域配置
CORS_ALLOW_ALL_ORIGINS=False
CORS_ALLOW_CREDENTIALS=True
CORS_ALLOWED_ORIGINS=http://${SERVER_IP}:${FRONTEND_PORT}

# Django安全配置
SECRET_KEY=placeholder_will_be_replaced

# 数据库配置（使用docker-compose中的变量）
DB_HOST=mysql
DB_PORT=3306
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_DB=0

# Django管理员配置
ADMIN_ACCOUNT=$DJANGO_ADMIN_ACCOUNT
ADMIN_INITIAL_PASSWORD=$DJANGO_ADMIN_PASSWORD
EOF

# 步骤6: 构建镜像并启动容器
print_step 6 6 "构建镜像并启动容器"

# 获取阿里云镜像仓库信息
echo -e "${GREEN}🔑 请输入阿里云镜像仓库登录信息:${NC}"
read -p "💡 阿里云镜像仓库地址 (默认: registry.cn-chengdu.aliyuncs.com): " registry_url
registry_url=${registry_url:-registry.cn-chengdu.aliyuncs.com}
read -p "💡 阿里云镜像仓库命名空间: " registry_namespace
read -p "💡 阿里云镜像仓库用户名: " registry_username
read -s -p "💡 阿里云镜像仓库密码: " registry_password
echo

# 登录阿里云镜像仓库
if ! docker_registry_login_with_retry "$registry_url" "$registry_username" "$registry_password"; then
    echo -e "${RED}❌ 无法登录阿里云镜像仓库，请检查凭据后重试${NC}"
    exit 1
fi

# 复制远程镜像配置文件
echo -e "${GREEN}📝 使用远程镜像配置...${NC}"
if ! cp "$CONFIG_DIR/docker-compose-remote.yml" "$PROJECT_DIR/docker-compose.yml"; then
    echo -e "${RED}❌ 复制docker-compose配置文件失败${NC}"
    exit 1
fi

# 拉取镜像
echo -e "${GREEN}📥 从阿里云镜像仓库拉取镜像...${NC}"
cd $PROJECT_DIR
if ! docker_compose_pull_with_retry; then
    echo -e "${RED}❌ 拉取镜像失败，请检查网络连接和镜像是否存在${NC}"
    exit 1
fi

# 使用拉取的后端镜像生成 SECRET_KEY
echo -e "${GREEN}🔑 生成Django SECRET_KEY...${NC}"
if ! generate_django_secret_key "$PROJECT_DIR/configs/env/.env.production" "$registry_url/$registry_namespace/msdps_backend:v1" "$PROJECT_DIR"; then
    echo -e "${RED}❌ SECRET_KEY生成失败，部署终止${NC}"
    exit 1
fi

# 启动所有容器
echo -e "${GREEN}🚀 启动所有容器...${NC}"
if ! docker_compose_up_with_retry; then
    echo -e "${RED}❌ 容器启动失败，请检查错误信息并重试${NC}"
    exit 1
fi

print_separator
echo -e "${GREEN}✅ 部署成功！${NC}"
echo -e "${CYAN}📝 访问信息：${NC}"
echo -e "  🌐 前端应用: http://${SERVER_IP}:${FRONTEND_PORT}"
echo -e "  🔧 Django管理后台: http://${SERVER_IP}:${BACKEND_PORT}/admin"
echo -e "  👤 管理员账号: admin"
echo -e "  🔑 管理员初始密码: 123Abc456"
print_separator