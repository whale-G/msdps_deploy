# MSDPS Deploy 🚀

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange)](https://ubuntu.com/)
[![Docker](https://img.shields.io/badge/Docker-required-blue)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-required-blue)](https://docs.docker.com/compose/)

> 一个高度定制化的质谱数据处理系统部署工具，用于在Linux环境下快速部署完整的MSDPS的Web服务。

<br/>

## 🏗️ 服务架构

```mermaid
graph LR
    Client[客户端] --> Nginx[前端Nginx:18080]
    Nginx --> Frontend[前端服务]
    Nginx --> Backend[后端Django:18000]
    Backend --> MySQL[MySQL数据库]
    Backend --> Redis[Redis缓存]
    Backend --> Celery[Celery Worker]
    Celery --> Redis
```

## 📑 目录

- [服务架构](#-服务架构)
- [系统要求](#-系统要求)
- [目录结构](#-目录结构)
- [快速开始](#-快速开始)
- [详细部署流程](#-详细部署流程)
  - [Git加速配置](#1-git加速配置可选)
  - [部署交互配置](#2--部署交互配置)
    - [项目代码克隆](#-项目代码克隆)
    - [服务端口配置](#-服务端口配置)
    - [环境变量配置](#-环境变量配置)
- [注意事项](#️-注意事项)
  - [部署前检查](#1-部署前请确保)
  - [故障排查指南](#2-故障排查)

## 💻 系统要求

- Ubuntu服务器（推荐20.04）
- Docker和Docker Compose`（可选，脚本会自动安装）`
- Git

<div STYLE="page-break-after: always;"></div>

## 📁 目录结构

```tree
msdps_deploy/
├── configs/                        # 配置文件目录
│   ├── docker-compose.yml          # Docker服务编排配置
│   ├── docker-compose.env          # Docker环境变量配置
│   ├── env/                        # 环境变量配置目录
│   │   ├── .env                    # Django基本环境变量
│   │   ├── .env.production         # Django生产环境变量
│   │   ├── mysql.env               # MySQL环境变量
│   │   └── redis.env               # Redis环境变量
│   ├── mysql/                      # MySQL配置目录
│   │   └── init.sql                # MySQL初始化脚本
│   ├── redis/                      # Redis配置目录
│   │   └── redis.conf              # Redis配置文件
│   ├── backend/                    # 后端服务配置目录
│   │   ├── Dockerfile              # 后端镜像构建文件
│   │   └── entrypoint.sh           # 后端容器启动脚本
│   └── frontend/                   # 前端服务配置目录
│       ├── Dockerfile              # 前端镜像构建文件
│       └── nginx.conf              # Nginx配置文件
└── scripts/                        # 部署脚本目录
    └── Ubuntu/                     # Ubuntu专用脚本
        ├── deploy.sh               # 一键部署脚本
        ├── source-config.sh        # 系统镜像源配置脚本
        ├── deploy-utils.sh         # 部署工具脚本
        ├── git-utils.sh            # Git相关工具脚本
        ├── docker-utils.sh         # Docker相关工具脚本
        └── django-utils.sh         # Django配置工具脚本
```

## 🚀 快速开始

1. 克隆部署项目：
```bash
# 克隆项目
git clone https://github.com/whale-G/msdps_deploy.git
# 找到部署脚本
cd msdps_deploy/scripts/Ubuntu
# 赋予执行权限
chmod +x ./*.sh
```

2. 配置系统镜像源`（可选）`：
```bash
# 配置项：
# 1. apt下载镜像源为阿里云源
# 2. git加速
./source-config.sh
```

3. 启动一键部署脚本：
```bash
./deploy.sh
```

<div STYLE="page-break-after: always;"></div>

## 📖 详细部署流程

### 1. Git加速配置（可选）

> 如果服务器可以正常访问Github，可以跳过此步骤

a. 备份hosts文件：
```bash
sudo cp /etc/hosts /etc/hosts.bak
```

b. 获取Github相关IP：
```bash
# 获取github.com的IP，请记录输出的IP地址
nslookup github.com

# 获取github.global.ssl.fastly.net的IP，请记录输出的IP地址
nslookup github.global.ssl.fastly.net
```

c. 配置hosts文件：
```bash
# 添加GitHub加速配置到hosts文件
# 请将下面的命令中的GITHUB_IP和GITHUB_FASTLY_IP替换为上一步获取到的实际IP地址
sudo bash -c 'cat << EOF >> /etc/hosts

# GitHub加速配置
GITHUB_FASTLY_IP github.global.ssl.fastly.net
GITHUB_FASTLY_IP http://github.global.ssl.fastly.net
GITHUB_FASTLY_IP https://github.global.ssl.fastly.net

GITHUB_IP github.com
GITHUB_IP http://github.com
GITHUB_IP https://github.com
EOF'
```

d. 刷新DNS缓存：
```bash
# 重启DNS服务
sudo systemctl restart systemd-resolved
```

e. 验证配置（可选）：
```bash
# 测试访问GitHub
ping github.com

# 如果ping成功，说明配置生效
```

> 注意：请确保将命令中的 `GITHUB_IP` 和 `GITHUB_FASTLY_IP` 替换为实际获取到的IP地址。

<div STYLE="page-break-after: always;"></div>

### 2. 🔄 部署交互配置

在部署过程中，脚本会要求您进行以下配置：

#### 📦 项目代码克隆

首先，脚本会克隆前端和后端项目代码：

![克隆代码](static/克隆代码.png)

> 💡 **提示**：如果看到克隆相关的警告信息，且您确认这是首次部署，可以安全地忽略这些警告。

#### 🌐 服务端口配置

接下来，您需要配置Web服务的访问端口：

![配置端口](static/配置端口.png)

| 服务 | 默认端口 | 说明 |
|------|---------|------|
| 前端 | 18080 | 用于访问网站界面 |
| 后端 | 18000 | 用于API调用 |

> ⚠️ **重要提示**：
> - 这些端口将在服务器上对外开放
> - 直接按回车键将使用默认端口
> - 如需自定义，请确保输入的端口未被占用

#### 🔐 环境变量配置

接下来，您需要设置项目的核心环境变量：

![项目环境变量配置](static/项目环境变量配置.png)

| 配置项 | 用途 | 安全建议 |
|--------|------|----------|
| `MySQL root密码` | MySQL根用户密码 | 使用强密码 |
| `MySQL数据库名` | 项目专用数据库 | 避免使用常见名称 |
| `MySQL用户名` | 数据库访问账号 | 避免使用默认用户名 |
| `MySQL密码` | 数据库访问密码 | 使用强密码 |
| `Redis密码` | Redis访问凭证 | 使用强密码 |
| `Django管理员用户名` | 后台管理账号 | 避免使用admin |
| `Django管理员密码` | 后台管理密码 | 使用强密码 |

> 🛡️ **安全提示**：
> - 生产环境请使用高强度密码
> - 建议密码包含大小写字母、数字和特殊字符
> - 密码长度建议不少于8位
> - 请妥善保存所有配置信息

#### web服务镜像构建


<br/><br/><br/>

## ⚠️ 注意事项

1. 部署前请确保：
   - 服务器防火墙已开放相应端口
   - 有足够的磁盘空间（建议 ≥ 20GB）
   - 已备份重要数据

2. 故障排查：
   - 查看容器日志：`docker logs <容器名>`
   - 检查服务状态：`docker-compose ps`
   - 查看资源使用：`docker stats`
