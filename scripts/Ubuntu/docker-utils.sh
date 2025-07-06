#!/bin/bash

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查Docker和Docker Compose是否安装
check_docker_installation() {
    echo -e "${GREEN}🔍 检查Docker和Docker Compose安装状态...${NC}"
    
    local docker_installed=false
    local docker_compose_plugin_installed=false
    local docker_compose_legacy_installed=false
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        docker_installed=true
        echo -e "${GREEN}✅ Docker已安装${NC}"
        echo "📋 Docker版本: $(docker --version)"
    else
        echo -e "${YELLOW}❌ Docker未安装${NC}"
    fi
    
    # 检查新版Docker Compose (plugin)
    if docker compose version &> /dev/null; then
        docker_compose_plugin_installed=true
        echo -e "${GREEN}✅ Docker Compose Plugin已安装${NC}"
        echo "📋 Docker Compose版本: $(docker compose version --short)"
    else
        echo -e "${YELLOW}❌ Docker Compose Plugin未安装${NC}"
    fi
    
    # 检查旧版Docker Compose
    if command -v docker-compose &> /dev/null; then
        docker_compose_legacy_installed=true
        echo -e "${GREEN}ℹ️ 传统版Docker Compose已安装${NC}"
        echo "📋 版本: $(docker-compose --version)"
    else
        echo -e "${YELLOW}ℹ️ 传统版Docker Compose未安装${NC}"
    fi
    
    # 返回检查结果
    if [ "$docker_installed" = true ] && [ "$docker_compose_plugin_installed" = true ]; then
        return 0  # Docker和新版Compose都已安装
    else
        return 1  # 需要安装
    fi
}

# 检查Docker版本类型（snap还是apt）
check_docker_version_type() {
    if snap list | grep -q "docker"; then
        echo "snap"
    else
        echo "apt"
    fi
}

# 启动snap版本的Docker
start_snap_docker() {
    echo -e "${GREEN}🚀 正在启动Snap版本的Docker服务...${NC}"
    
    # 检查Docker是否正在运行
    if ! snap services | grep -q "docker.*active"; then
        echo -e "${YELLOW}⚠️ Docker服务未运行，正在启动...${NC}"
        snap start docker
    fi
    
    echo -e "${GREEN}🔄 重启Docker服务...${NC}"
    snap restart docker
    
    echo -e "${GREEN}⏳ 等待Docker服务就绪...${NC}"
    sleep 5
    
    # 验证服务状态
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker服务运行正常${NC}"
        return 0
    else
        echo -e "${RED}❌ Docker服务启动失败${NC}"
        return 1
    fi
}

# 启动apt版本的Docker
start_apt_docker() {
    echo -e "${GREEN}🚀 正在启动APT版本的Docker服务...${NC}"
    
    # 检查Docker是否正在运行
    if ! systemctl is-active docker >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ Docker服务未运行，正在启动...${NC}"
        systemctl start docker
    fi
    
    echo -e "${GREEN}🔄 重启Docker服务...${NC}"
    systemctl daemon-reload
    systemctl restart docker
    
    # 验证服务状态
    if systemctl is-active docker >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker服务运行正常${NC}"
        return 0
    else
        echo -e "${RED}❌ Docker服务启动失败${NC}"
        return 1
    fi
}

# 安装apt版本的Docker和Docker Compose
install_apt_docker() {
    echo -e "${GREEN}🚀 开始安装Docker和Docker Compose...${NC}"
    
    echo -e "${GREEN}📦 更新包索引...${NC}"
    apt-get update
    
    echo -e "${GREEN}📥 安装必要的依赖包...${NC}"
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
        
    echo -e "${GREEN}🔑 添加Docker GPG密钥...${NC}"
    curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo -e "${GREEN}📝 配置Docker仓库...${NC}"
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
    echo -e "${GREEN}⚙️ 安装Docker Engine...${NC}"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    echo -e "${GREEN}🔄 启动Docker服务...${NC}"
    systemctl start docker
    systemctl enable docker
    
    if ! docker --version; then
        echo -e "${RED}❌ Docker安装失败，请检查安装日志${NC}"
        return 1
    fi

    if command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}ℹ️ 检测到已安装传统版Docker Compose${NC}"
        echo -e "${GREEN}✅ 当前版本: $(docker-compose --version)${NC}"
    fi

    echo -e "${GREEN}📥 安装Docker Compose Plugin...${NC}"
    if apt-get install -y docker-compose-plugin; then
        echo -e "${GREEN}✅ Docker Compose Plugin安装成功${NC}"
        echo "📋 版本: $(docker compose version --short)"
    else
        echo -e "${RED}❌ Docker Compose Plugin安装失败${NC}"
        return 1
    fi

    echo -e "${GREEN}✨ Docker和Docker Compose安装完成${NC}"
    return 0
}

# 配置Docker镜像源
configure_docker_mirror() {
    echo -e "${GREEN}📝 配置Docker镜像加速...${NC}"
    cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": [
        "https://docker.xuanyuan.me",
        "https://docker.1ms.run"
    ]
}
EOF

    echo -e "${GREEN}✅ Docker镜像源配置成功！${NC}"

    # 重启Docker服务
    echo -e "${GREEN}重启Docker服务...${NC}"
    systemctl daemon-reload
    systemctl restart docker 
}

# 检查端口占用
check_port_conflicts() {
    local ports=("$1" "$2")
    local conflict=false

    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${RED}❌ 错误：端口参数不能为空${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}🔍 检查端口占用情况...${NC}"
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            echo -e "${RED}⚠️ 端口 $port 已被占用${NC}"
            conflict=true
        fi
    done
    
    if [ "$conflict" = true ]; then
        echo -e "${RED}❌ 存在端口冲突，请修改配置后重试${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ 端口检查通过${NC}"
}

# 检查容器名称冲突并清理已存在的项目容器
check_container_conflicts() {
    local containers=("msdps_mysql" "msdps_redis" "msdps_backend" "msdps_frontend" "msdps_scheduler" "msdps_celery_worker")
    local conflict=false
    local need_cleanup=false
    
    echo -e "${GREEN}🔍 检查容器名称冲突...${NC}"
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
            echo -e "${YELLOW}⚠️ 发现已存在的容器: $container${NC}"
            need_cleanup=true
            
            # 检查容器是否在运行
            if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
                echo -e "${YELLOW}📌 容器 $container 正在运行，将被停止并移除${NC}"
                docker stop "$container" >/dev/null 2>&1
            else
                echo -e "${YELLOW}📌 容器 $container 未运行，将被移除${NC}"
            fi
            docker rm "$container" >/dev/null 2>&1
        fi
    done
    
    if [ "$need_cleanup" = true ]; then
        echo -e "${GREEN}✅ 已清理所有冲突的容器${NC}"
    else
        echo -e "${GREEN}✅ 未发现需要清理的容器${NC}"
    fi
}

# Docker Compose构建函数
docker_compose_build_with_retry() {
    local max_retries=3
    local retry_count=0
    local wait_time=30

    while [ $retry_count -lt $max_retries ]; do
        echo -e "${GREEN}🏗️ 尝试构建镜像 (尝试 $((retry_count + 1))/$max_retries)${NC}"
        
        if docker compose build; then
            echo -e "${GREEN}✅ 镜像构建成功！${NC}"
            return 0
        else
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}⚠️ 构建失败，等待 ${wait_time} 秒后重试...${NC}"
                
                echo -e "${YELLOW}🧹 清理构建缓存...${NC}"
                docker image prune -f
                
                sleep $wait_time
                
                # 增加等待时间，指数退避
                wait_time=$((wait_time * 2))
            else
                echo -e "${RED}❌ 达到最大重试次数，构建失败${NC}"
                return 1
            fi
        fi
    done
}

# Docker Compose启动函数
docker_compose_up_with_retry() {
    local max_retries=3
    local retry_count=0
    local wait_time=5

    # 首先检查容器名称冲突并清理
    check_container_conflicts

    echo -e "${GREEN}🚀 开始启动容器服务...${NC}"
    
    while [ $retry_count -lt $max_retries ]; do
        echo -e "${GREEN}🔄 尝试启动容器 (尝试 $((retry_count + 1))/$max_retries)${NC}"
        
        # 启动容器但忽略退出状态
        echo -e "${GREEN}启动所有容器...${NC}"
        docker compose up -d || true
        
        echo -e "${GREEN}⏳ 等待容器启动和健康检查 (10秒)...${NC}"
        sleep 10
        # 检查容器状态和日志
        local unhealthy_containers=()
        echo -e "\n${GREEN}📋 ========== 容器状态检查 ==========${NC}"
        
        for container in $(docker compose ps --services); do
            echo -e "\n${YELLOW}检查容器: msdps_${container}${NC}"
            
            # 获取容器ID（如果存在）
            local container_id=$(docker ps -qf "name=msdps_${container}" 2>/dev/null)
            
            if [ -z "$container_id" ]; then
                echo -e "${RED}容器未运行或不存在${NC}"
                unhealthy_containers+=("msdps_${container}")
                continue
            fi
            
            # 获取详细状态
            local status=$(docker inspect --format '{{.State.Status}}' "$container_id")
            local health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")
            local started_at=$(docker inspect --format '{{.State.StartedAt}}' "$container_id")
            
            echo "状态: $status"
            echo "健康状态: $health"
            echo "启动时间: $started_at"
            
            # 如果容器不健康，获取更多信息
            if [ "$status" != "running" ] || [ "$health" = "unhealthy" ]; then
                unhealthy_containers+=("msdps_${container}")
                
                echo -e "\n${RED}⚠️ 容器异常，详细信息：${NC}"
                
                echo -e "\n${YELLOW}🔍 容器环境变量:${NC}"
                docker exec "$container_id" env 2>/dev/null || echo "无法获取环境变量"
                
                echo -e "\n${YELLOW}📜 最近的容器日志:${NC}"
                docker logs --tail 50 "$container_id" 2>&1 || echo "无法获取日志"
                
                # 如果是后端容器，尝试获取更多Python相关信息
                if [ "$container" = "backend" ]; then
                    echo -e "\n${YELLOW}🐍 Django/Python 错误日志:${NC}"
                    docker exec "$container_id" python -c "import sys; print('Python 路径:', sys.path)" 2>/dev/null || echo "无法获取Python路径"
                    docker exec "$container_id" pip list 2>/dev/null || echo "无法获取已安装的Python包"
                fi
            fi
        done
        
        if [ ${#unhealthy_containers[@]} -eq 0 ]; then
            echo -e "\n${GREEN}✅ 所有容器启动成功且健康！${NC}"
            return 0
        else
            echo -e "\n${RED}❌ 以下容器未能正常启动或不健康:${NC}"
            printf '%s\n' "${unhealthy_containers[@]}"
            
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}⏳ 等待 ${wait_time} 秒后重试...${NC}"
                sleep $wait_time
                wait_time=$((wait_time * 2))
            else
                echo -e "${RED}达到最大重试次数，启动失败。${NC}"
                echo -e "${RED}请检查以上日志信息，特别是环境变量和Python包的安装状态。${NC}"
                return 1
            fi
        fi
    done
}

# 登录阿里云镜像仓库
docker_registry_login_with_retry() {
    local registry_url="$1"
    local registry_username="$2"
    local registry_password="$3"
    local max_retries=3
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $max_retries ]; do
        echo -e "${GREEN}🔑 尝试登录阿里云镜像仓库 (尝试 $((retry_count + 1))/$max_retries)${NC}"
        
        if echo "$registry_password" | docker login --username "$registry_username" --password-stdin "$registry_url"; then
            echo -e "${GREEN}✅ 登录成功！${NC}"
            return 0
        else
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}⚠️ 登录失败，等待 ${wait_time} 秒后重试...${NC}"
                sleep $wait_time
            else
                echo -e "${RED}❌ 达到最大重试次数，登录失败${NC}"
                return 1
            fi
        fi
    done
}

# 替换docker-compose.yml中的镜像配置
update_docker_compose_images() {
    local compose_file="$1"
    local registry_url="$2"
    local registry_namespace="$3"
    local max_retries=3
    local retry_count=0
    
    echo -e "${GREEN}📝 更新docker-compose.yml中的镜像配置...${NC}"
    
    # 创建备份
    local backup_file="${compose_file}.bak"
    cp "$compose_file" "$backup_file"
    
    while [ $retry_count -lt $max_retries ]; do
        echo -e "${GREEN}🔄 尝试更新配置 (尝试 $((retry_count + 1))/$max_retries)${NC}"
        
        # 创建临时文件
        local temp_file=$(mktemp)
        cp "$compose_file" "$temp_file"
        
        # 定义镜像标签
        local backend_image="${registry_url}/${registry_namespace}/msdps_backend:v1"
        local frontend_image="${registry_url}/${registry_namespace}/msdps_frontend:v1"
        local scheduler_image="${registry_url}/${registry_namespace}/msdps_scheduler:v1"
        local celery_worker_image="${registry_url}/${registry_namespace}/msdps_celery_worker:v1"
        local mysql_image="${registry_url}/${registry_namespace}/msdps_mysql:8.0"
        local redis_image="${registry_url}/${registry_namespace}/msdps_redis:6.2"
        
        # 替换镜像配置
        sed -i "/backend:/,/dockerfile:/c\  backend:\n    image: $backend_image" "$temp_file"
        sed -i "/scheduler:/,/dockerfile:/c\  scheduler:\n    image: $scheduler_image" "$temp_file"
        sed -i "/celery_worker:/,/dockerfile:/c\  celery_worker:\n    image: $celery_worker_image" "$temp_file"
        sed -i "/frontend:/,/dockerfile:/c\  frontend:\n    image: $frontend_image" "$temp_file"
        sed -i "s|image: mysql:8.0|image: $mysql_image|" "$temp_file"
        sed -i "s|image: redis:6.2|image: $redis_image|" "$temp_file"
        
        # 检查替换是否成功
        if grep -q "build:" "$temp_file"; then
            echo -e "${YELLOW}⚠️ 配置更新失败，正在清理...${NC}"
            rm "$temp_file"
            
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}⚠️ 等待 5 秒后重试...${NC}"
                sleep 5
            else
                echo -e "${RED}❌ 达到最大重试次数，还原备份...${NC}"
                mv "$backup_file" "$compose_file"
                echo -e "${GREEN}✅ 已还原到原始配置${NC}"
                return 1
            fi
            continue
        fi
        
        # 替换成功，移动临时文件
        mv "$temp_file" "$compose_file"
        echo -e "${GREEN}✅ 镜像配置更新成功！${NC}"
        
        # 清理备份文件
        rm "$backup_file"
        return 0
    done
}

# 拉取阿里云镜像
docker_compose_pull_with_retry() {
    local max_retries=3
    local retry_count=0
    local wait_time=30
    
    while [ $retry_count -lt $max_retries ]; do
        echo -e "${GREEN}📥 尝试拉取镜像 (尝试 $((retry_count + 1))/$max_retries)${NC}"
        
        if docker compose pull; then
            echo -e "${GREEN}✅ 镜像拉取成功！${NC}"
            return 0
        else
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}⚠️ 拉取失败，等待 ${wait_time} 秒后重试...${NC}"
                sleep $wait_time
            else
                echo -e "${RED}❌ 达到最大重试次数，拉取失败${NC}"
                return 1
            fi
        fi
    done
}

# 重命名从镜像仓库拉取的镜像为本地镜像名称
rename_registry_images() {
    local registry_url="$1"
    local registry_namespace="$2"
    
    echo -e "${GREEN}🏷️ 重命名镜像...${NC}"
    
    # 定义镜像映射关系（远程镜像:本地镜像）
    local image_pairs=(
        "${registry_url}/${registry_namespace}/msdps_backend:v1:msdps_backend"
        "${registry_url}/${registry_namespace}/msdps_frontend:v1:msdps_frontend"
        "${registry_url}/${registry_namespace}/msdps_scheduler:v1:msdps_scheduler"
        "${registry_url}/${registry_namespace}/msdps_celery_worker:v1:msdps_celery_worker"
        "${registry_url}/${registry_namespace}/msdps_mysql:8.0:msdps_mysql"
        "${registry_url}/${registry_namespace}/msdps_redis:6.2:msdps_redis"
    )
    
    for pair in "${image_pairs[@]}"; do
        local remote_image="${pair%%:*}"
        local local_image="${pair##*:}"
        
        echo -e "${GREEN}📝 重命名 $remote_image 为 $local_image ${NC}"
        if ! docker tag "$remote_image" "$local_image"; then
            echo -e "${RED}❌ 重命名镜像失败: $remote_image${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}✅ 镜像重命名完成${NC}"
    return 0
}

# 主函数：处理Docker环境
setup_docker_environment() {
    echo -e "${GREEN}🔍 检查Docker环境...${NC}"
    
    if check_docker_installation; then
        echo -e "${GREEN}✅ Docker环境已存在，进行版本检查...${NC}"
        
        local docker_type=$(check_docker_version_type)
        echo -e "${GREEN}📦 检测到${docker_type}版本的Docker${NC}"
        
        # 根据版本类型启动服务
        if [ "$docker_type" = "snap" ]; then
            start_snap_docker
        else
            start_apt_docker
        fi
    else
        echo -e "${YELLOW}📥 Docker环境未安装，开始安装...${NC}"
        install_apt_docker
    fi

    # 统一配置镜像源
    configure_docker_mirror || return 1
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker服务未正常运行${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✨ Docker环境配置完成！${NC}"
    return 0
}

# 导出主函数
export -f setup_docker_environment
export -f check_port_conflicts
export -f docker_compose_build_with_retry
export -f docker_compose_up_with_retry
export -f docker_registry_login_with_retry
export -f update_docker_compose_images
export -f docker_compose_pull_with_retry
export -f rename_registry_images