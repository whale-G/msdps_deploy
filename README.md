# msdps_deploy
A highly customized mass spectrometry data processing system, this is the Linux environment deployment script for this project.

## 目录结构说明

- `configs/`: 包含所有配置文件
  - `docker-compose.yml`: Docker服务编排配置
  - `docker-compose.env`: Docker环境变量配置
  - `env/`: Django应用环境变量配置
  - `mysql/`: MySQL数据库配置
  - `redis/`: Redis缓存配置
  - `backend/`: 后端服务配置
  - `frontend/`: 前端服务配置

- `scripts/`: 部署和配置脚本
  - `Ubuntu/`: Ubuntu系统专用脚本
    - `deploy.sh`: 一键部署脚本
    - `source-config.sh`: 系统源配置脚本

## 部署说明

1. 系统要求：
   - Ubuntu服务器（推荐Ubuntu 20.04或更高版本）
   - Docker和Docker Compose已安装
   - Git已安装

2. 部署步骤：
   - 克隆项目到服务器
   - 执行source-config.sh配置系统源
   - 执行deploy.sh进行一键部署
   - 按提示输入必要的配置信息

3. 配置说明：
   - 前端服务默认端口：18080
   - 后端服务默认端口：18000
   - 数据库和Redis服务仅内部访问

4. 访问地址：
   - 网站访问：http://服务器IP:18080
   - API访问：http://服务器IP:18000

## 注意事项

1. 请确保服务器防火墙已开放相应端口
2. 首次部署需要较长时间，请耐心等待
3. 建议在部署前备份重要数据
4. 如遇问题，请查看日志文件进行排查

## 详细部署流程

1. 配置git国内加速

    ```shell
    git config --global url."https://ghproxy.com/https://github.com".insteadOf "https://github.com"
    ```

2. git clone本项目至本地，找到`deploy.sh`脚本所在目录

    ```shell
    git clone https://github.com/whale-G/msdps_deploy.git

    # deploy.sh
    cd msdps_deploy/Ubuntu/scripts
    ```

3. 赋予部署脚本可执行权限，并执行脚本

    ```shell
    # 赋予权限
    chmod +x deploy.sh
    chmod +x source-config.sh
    chmod +x docker-utils.sh
    chmod +x git-utils.sh

    # 执行脚本
    ./source-config.sh      # 更换国内下载源
    ./deploy.sh             # 一键部署脚本
    ```

4. 查看部署脚本输出的信息，修复报错或者访问服务。
