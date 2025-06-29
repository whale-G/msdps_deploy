#!/bin/bash

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查Docker和Docker Compose是否安装
check_docker_installation() {
    echo -e "${GREEN}检查Docker和Docker Compose安装状态...${NC}"
    
    local docker_installed=false
    local docker_compose_plugin_installed=false
    local docker_compose_legacy_installed=false
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        docker_installed=true
        echo -e "${GREEN}Docker已安装${NC}"
        echo "Docker版本: $(docker --version)"
    else
        echo -e "${YELLOW}Docker未安装${NC}"
    fi
    
    # 检查新版Docker Compose (plugin)
    if docker compose version &> /dev/null; then
        docker_compose_plugin_installed=true
        echo -e "${GREEN}Docker Compose Plugin已安装${NC}"
        echo "Docker Compose版本: $(docker compose version --short)"
    else
        echo -e "${YELLOW}Docker Compose Plugin未安装${NC}"
    fi
    
    # 检查旧版Docker Compose
    if command -v docker-compose &> /dev/null; then
        docker_compose_legacy_installed=true
        echo -e "${GREEN}传统版Docker Compose已安装${NC}"
        echo "版本: $(docker-compose --version)"
    else
        echo -e "${YELLOW}传统版Docker Compose未安装${NC}"
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
    echo -e "${GREEN}正在启动Snap版本的Docker服务...${NC}"
    
    # 检查Docker是否正在运行
    if ! snap services | grep -q "docker.*active"; then
        echo -e "${YELLOW}Docker服务未运行，正在启动...${NC}"
        snap start docker
    fi
    
    # 重启Docker服务
    echo -e "${GREEN}重启Docker服务...${NC}"
    snap restart docker
    
    # 等待服务就绪
    echo -e "${GREEN}等待Docker服务就绪...${NC}"
    sleep 5
    
    # 验证服务状态
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}Docker服务运行正常${NC}"
        return 0
    else
        echo -e "${RED}Docker服务启动失败${NC}"
        return 1
    fi
}

# 启动apt版本的Docker
start_apt_docker() {
    echo -e "${GREEN}正在启动APT版本的Docker服务...${NC}"
    
    # 检查Docker是否正在运行
    if ! systemctl is-active docker >/dev/null 2>&1; then
        echo -e "${YELLOW}Docker服务未运行，正在启动...${NC}"
        systemctl start docker
    fi
    
    # 重启Docker服务
    echo -e "${GREEN}重启Docker服务...${NC}"
    systemctl daemon-reload
    systemctl restart docker
    
    # 验证服务状态
    if systemctl is-active docker >/dev/null 2>&1; then
        echo -e "${GREEN}Docker服务运行正常${NC}"
        return 0
    else
        echo -e "${RED}Docker服务启动失败${NC}"
        return 1
    fi
}

# 安装apt版本的Docker和Docker Compose
install_apt_docker() {
    echo -e "${GREEN}开始安装Docker和Docker Compose...${NC}"
    
    # 更新包索引
    apt-get update
    
    # 安装必要的依赖包
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
        
    # 添加清华源的Docker GPG密钥
    curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 设置清华Docker仓库
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
    # 更新apt包索引
    apt-get update
    
    # 安装Docker Engine
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # 启动并启用Docker服务
    systemctl start docker
    systemctl enable docker
    
    # 验证Docker安装
    if ! docker --version; then
        echo -e "${RED}Docker安装可能未成功，请检查安装日志${NC}"
        return 1
    fi

    # 检查是否已安装旧版docker-compose
    if command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}检测到已安装传统版Docker Compose，将保持不变${NC}"
        echo -e "${GREEN}当前版本: $(docker-compose --version)${NC}"
    fi

    # 安装新版Docker Compose Plugin
    echo -e "${GREEN}安装Docker Compose Plugin...${NC}"
    if apt-get install -y docker-compose-plugin; then
        echo -e "${GREEN}Docker Compose Plugin安装成功${NC}"
        echo "版本: $(docker compose version --short)"
    else
        echo -e "${RED}Docker Compose Plugin安装失败${NC}"
        return 1
    fi

    echo -e "${GREEN}Docker和Docker Compose安装完成${NC}"
    return 0
}

# 主函数：处理Docker环境
setup_docker_environment() {
    # 1. 检查是否已安装
    if check_docker_installation; then
        echo -e "${GREEN}Docker环境已存在，进行版本检查...${NC}"
        
        # 2. 检查版本类型并相应处理
        local docker_type=$(check_docker_version_type)
        echo -e "${GREEN}检测到${docker_type}版本的Docker${NC}"
        
        # 根据版本类型启动服务
        if [ "$docker_type" = "snap" ]; then
            start_snap_docker
        else
            start_apt_docker
        fi
    else
        # 3. 如果未安装，则安装apt版本
        echo -e "${YELLOW}Docker环境未完全安装，开始安装apt版本...${NC}"
        install_apt_docker
    fi
}

# 检查端口占用
check_port_conflicts() {
    local ports=("$1" "$2")  # 接收端口参数
    local conflict=false

    # 添加参数验证
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${RED}错误：端口参数不能为空${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}检查端口占用情况...${NC}"
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            echo -e "${RED}端口 $port 已被占用${NC}"
            conflict=true
        fi
    done
    
    if [ "$conflict" = true ]; then
        echo -e "${RED}存在端口冲突，请修改配置后重试${NC}"
        exit 1
    fi
}

# 检查容器名称冲突
check_container_conflicts() {
    local containers=("msdps_mysql" "msdps_redis" "msdps_backend" "msdps_frontend")
    local conflict=false
    
    echo -e "${GREEN}检查容器名称冲突...${NC}"
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
            echo -e "${RED}容器名 $container 已存在${NC}"
            conflict=true
        fi
    done
    
    if [ "$conflict" = true ]; then
        echo -e "${RED}存在容器名称冲突，请先清理同名容器${NC}"
        exit 1
    fi
}

# Docker Compose构建函数
docker_compose_build_with_retry() {
    local max_retries=3
    local retry_count=0
    local wait_time=30

    while [ $retry_count -lt $max_retries ]; do
        echo -e "${GREEN}尝试构建镜像 (尝试 $((retry_count + 1))/$max_retries)${NC}"
        
        if docker compose build; then
            echo -e "${GREEN}镜像构建成功！${NC}"
            return 0
        else
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}构建失败，等待 ${wait_time} 秒后重试...${NC}"
                
                # 清理构建缓存
                echo -e "${YELLOW}清理构建缓存...${NC}"
                docker builder prune -f
                
                sleep $wait_time
                
                # 增加等待时间，指数退避
                wait_time=$((wait_time * 2))
            else
                echo -e "${RED}达到最大重试次数，构建失败${NC}"
                return 1
            fi
        fi
    done
}

# Docker Compose启动函数
docker_compose_up_with_retry() {
    local max_retries=3
    local retry_count=0
    local wait_time=30

    while [ $retry_count -lt $max_retries ]; do
        echo -e "${GREEN}尝试启动容器 (尝试 $((retry_count + 1))/$max_retries)${NC}"
        
        if docker compose up -d; then
            echo -e "${GREEN}容器启动成功！${NC}"
            return 0
        else
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}启动失败，等待 ${wait_time} 秒后重试...${NC}"
                
                # 清理可能的失败容器
                echo -e "${YELLOW}清理失败的容器...${NC}"
                docker compose down
                
                sleep $wait_time
                
                # 增加等待时间，指数退避
                wait_time=$((wait_time * 2))
            else
                echo -e "${RED}达到最大重试次数，启动失败${NC}"
                return 1
            fi
        fi
    done
}

# 导出主函数
export -f setup_docker_environment
export -f check_port_conflicts
export -f check_container_conflicts
export -f docker_compose_build_with_retry
export -f docker_compose_up_with_retry