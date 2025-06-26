# msdps_deploy
A highly customized mass spectrometry data processing system, this is the Linux environment deployment script for this project.

# 部署流程

1. 配置Git国内加速

    ```shell
    git config --global url."https://hub.fastgit.xyz".insteadOf "https://ghproxy.com/https://github.com".insteadOf "https://github.com"
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

    # 执行脚本
    ./source-config.sh      # 更换国内下载源
    ./deploy.sh             # 一键部署脚本
    ```

4. 查看部署脚本输出的信息，修复报错或者访问服务。
