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
    local docker_compose_installed=false
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        docker_installed=true
        echo -e "${GREEN}Docker已安装${NC}"
        echo "Docker版本: $(docker --version)"
    else
        echo -e "${YELLOW}Docker未安装${NC}"
    fi
    
    # 检查Docker Compose
    if command -v docker-compose &> /dev/null; then
        docker_compose_installed=true
        echo -e "${GREEN}Docker Compose已安装${NC}"
        echo "Docker Compose版本: $(docker-compose --version)"
    else
        echo -e "${YELLOW}Docker Compose未安装${NC}"
    fi
    
    # 返回检查结果
    if [ "$docker_installed" = true ] && [ "$docker_compose_installed" = true ]; then
        return 0  # 都已安装
    else
        return 1  # 至少有一个未安装
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

# 检查Docker Compose版本是否满足要求
check_compose_version() {
    local required_version="2.0.0"
    local current_version=$(docker-compose --version | awk '{print $3}' | tr -d ',' | sed 's/v//')
    
    # 比较版本号
    if [ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" = "$required_version" ]; then
        return 0  # 当前版本大于等于要求版本
    else
        return 1  # 当前版本小于要求版本
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
        
    # 添加Docker官方GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 设置Docker稳定版仓库
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
    # 更新apt包索引
    apt-get update
    
    # 安装Docker Engine
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # 安装Docker Compose
    apt-get install -y docker-compose
    
    # 启动并启用Docker服务
    systemctl start docker
    systemctl enable docker
    
    echo -e "${GREEN}Docker和Docker Compose安装完成${NC}"

    # 验证Docker安装
    if ! docker --version; then
        echo -e "${RED}Docker安装可能未成功，请检查安装日志${NC}"
        return 1
    fi

    # 检查Docker Compose版本并在需要时升级
    if ! check_compose_version; then
        echo -e "${YELLOW}当前Docker Compose版本低于要求，准备升级...${NC}"
        if upgrade_docker_compose; then
            echo -e "${GREEN}Docker Compose升级成功${NC}"
        else
            echo -e "${RED}Docker Compose升级失败，但不影响基本功能${NC}"
        fi
    else
        echo -e "${GREEN}Docker Compose版本满足要求${NC}"
    fi
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

# 升级Docker Compose到指定版本
upgrade_docker_compose() {
    echo "开始升级Docker Compose..."
    local upgrade_success=false
    
    # 检查当前版本
    local current_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    echo "当前Docker Compose版本: $current_version"
    
    # 备份当前版本
    if [ -f "/usr/local/bin/docker-compose" ]; then
        echo "备份当前Docker Compose..."
        sudo cp /usr/local/bin/docker-compose /usr/local/bin/docker-compose.backup
    fi
    
    # 尝试通过apt升级
    echo "尝试通过apt升级Docker Compose..."
    if apt-cache policy docker-compose | grep -q "2."; then
        # apt源中有2.x版本，使用apt升级
        echo "在apt源中找到新版本，开始升级..."
        if sudo apt-get update && sudo apt-get install -y docker-compose; then
            echo "apt升级成功！新版本为："
            docker-compose --version
            upgrade_success=true
        else
            echo "apt升级失败，尝试从GitHub下载..."
        fi
    else
        echo "apt源中没有找到2.x版本，尝试从GitHub下载..."
    fi
    
    # 如果apt升级失败，尝试从GitHub下载
    if [ "$upgrade_success" = false ]; then
        echo "从GitHub下载新版本Docker Compose..."
        if sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose.new; then
            # 设置执行权限
            sudo chmod +x /usr/local/bin/docker-compose.new
            
            # 测试新版本
            if /usr/local/bin/docker-compose.new version > /dev/null 2>&1; then
                # 如果测试成功，替换旧版本
                sudo mv /usr/local/bin/docker-compose.new /usr/local/bin/docker-compose
                echo "GitHub下载升级成功！新版本为："
                docker-compose --version
                upgrade_success=true
            else
                echo "新版本测试失败，正在回滚..."
                sudo rm -f /usr/local/bin/docker-compose.new
                if [ -f "/usr/local/bin/docker-compose.backup" ]; then
                    sudo cp /usr/local/bin/docker-compose.backup /usr/local/bin/docker-compose
                    echo "已恢复到原版本"
                fi
            fi
        else
            echo "GitHub下载失败，保持原版本不变"
            if [ -f "/usr/local/bin/docker-compose.backup" ]; then
                sudo cp /usr/local/bin/docker-compose.backup /usr/local/bin/docker-compose
            fi
        fi
    fi
    
    # 无论使用哪种方式升级，都处理备份文件
    if [ "$upgrade_success" = true ]; then
        echo "升级成功完成！"
        echo "备份文件将保留24小时: /usr/local/bin/docker-compose.backup"
        echo "如需回滚，请执行: sudo cp /usr/local/bin/docker-compose.backup /usr/local/bin/docker-compose"
        return 0
    else
        echo "升级失败，已回滚到原版本"
        return 1
    fi
}

# 导出主函数
export -f setup_docker_environment
export -f check_port_conflicts
export -f check_container_conflicts
export -f upgrade_docker_compose