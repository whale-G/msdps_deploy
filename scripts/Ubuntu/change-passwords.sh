#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 预设值定义
MYSQL_ROOT_PASSWORD=123Abc456
MYSQL_USER="msdps_db_user"
REDIS_PASSWORD=123Abc456

# 分隔线函数
print_separator() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
}

# 错误处理函数
handle_error() {
    echo -e "${RED}❌ 错误: $1${NC}"
    exit 1
}

# 检查是否有root权限
if [ "$(id -u)" -ne 0 ]; then
    handle_error "请使用root权限运行此脚本"
fi

# 检查docker是否运行
if ! docker info > /dev/null 2>&1; then
    handle_error "Docker服务未运行"
fi

# 获取真实用户和主目录
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
PROJECT_DIR="$USER_HOME/msdps_web"

print_separator
echo -e "${BOLD}🔐 MSDPS Web服务密码修改工具${NC}\n"

# 确认用户已备份数据
echo -e "${YELLOW}⚠️ 警告: 在修改密码之前，请确保您已经备份了重要数据。${NC}"
read -p "是否继续? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}已取消操作${NC}"
    exit 1
fi

# 获取新的密码
echo -e "\n${BOLD}请输入新的密码信息：${NC}"

read -p "MySQL root密码: " mysql_root_password
read -p "MySQL 用户密码: " mysql_password
read -p "Redis 密码: " redis_password

# 验证密码不为空
if [ -z "$mysql_root_password" ] || [ -z "$mysql_password" ] || [ -z "$redis_password" ]; then
    handle_error "所有密码都不能为空"
fi

print_separator
echo -e "${YELLOW}即将执行以下操作：${NC}"
echo "1. 修改 MySQL root 密码"
echo "2. 修改 MySQL 用户密码"
echo "3. 修改 Redis 密码"
echo "4. 更新 Django 环境配置"
echo "5. 重启相关服务"

read -p "确认执行? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}已取消操作${NC}"
    exit 1
fi

# 停止相关服务
echo -e "\n${YELLOW}正在停止相关服务...${NC}"
docker compose -f $PROJECT_DIR/docker-compose.yml stop mysql redis backend scheduler celery_worker

# 修改 MySQL 密码
echo -e "\n${YELLOW}正在修改 MySQL 密码...${NC}"
if ! docker compose -f $PROJECT_DIR/docker-compose.yml exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" << EOF
ALTER USER 'root'@'%' IDENTIFIED BY '$mysql_root_password';
ALTER USER '$MYSQL_USER'@'%' IDENTIFIED BY '$mysql_password';
FLUSH PRIVILEGES;
EOF
then
    handle_error "MySQL 密码修改失败"
fi

# 修改 Redis 密码
echo -e "\n${YELLOW}正在修改 Redis 密码...${NC}"
if ! docker compose -f $PROJECT_DIR/docker-compose.yml exec -T redis redis-cli -a "$REDIS_PASSWORD" CONFIG SET requirepass "$redis_password"; then
    handle_error "Redis 密码修改失败"
fi

# 更新环境变量文件
echo -e "\n${YELLOW}正在更新环境变量文件...${NC}"

# 更新 MySQL 环境变量
sed -i "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$mysql_root_password/" $PROJECT_DIR/configs/env/mysql.env
sed -i "s/MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$mysql_password/" $PROJECT_DIR/configs/env/mysql.env

# 更新 Redis 环境变量
sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$redis_password/" $PROJECT_DIR/configs/env/redis.env

# 更新 Django 环境变量
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$mysql_password/" $PROJECT_DIR/configs/env/.env.production
sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$redis_password/" $PROJECT_DIR/configs/env/.env.production

# 重启服务
echo -e "\n${YELLOW}正在重启服务...${NC}"
if ! docker compose -f $PROJECT_DIR/docker-compose.yml up -d --force-recreate mysql redis backend scheduler celery_worker; then
    handle_error "服务重启失败"
fi

# 验证服务状态
echo -e "\n${YELLOW}正在验证服务状态...${NC}"
sleep 10  # 等待服务启动

# 检查服务状态
if docker compose -f $PROJECT_DIR/docker-compose.yml ps | grep -q "Exit"; then
    handle_error "部分服务启动失败，请检查日志"
fi

print_separator
echo -e "${GREEN}✅ 密码修改成功！${NC}"
echo -e "\n${YELLOW}请妥善保管以下信息：${NC}"
echo "MySQL root 密码: $mysql_root_password"
echo "MySQL 用户密码: $mysql_password"
echo "Redis 密码: $redis_password"
print_separator

echo -e "\n${BOLD}🔍 建议执行以下操作：${NC}"
echo "1. 验证各项服务是否正常运行"
echo "2. 测试数据库和缓存连接是否正常"
echo "3. 确保web服务能正常访问"
echo -e "\n${YELLOW}如遇问题，请查看服务日志：${NC}"
echo "docker compose -f $PROJECT_DIR/docker-compose.yml logs" 