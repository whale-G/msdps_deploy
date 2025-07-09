# 使用Python 3.10作为基础镜像
FROM python:3.10

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 配置Debian镜像源并安装netcat
RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* && \
    echo 'Types: deb\n\
URIs: https://mirrors.aliyun.com/debian\n\
Suites: bookworm bookworm-updates bookworm-backports\n\
Components: main contrib non-free non-free-firmware\n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\
\n\
Types: deb\n\
URIs: https://mirrors.aliyun.com/debian-security\n\
Suites: bookworm-security\n\
Components: main contrib non-free non-free-firmware\n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' > /etc/apt/sources.list.d/debian.sources && \
    echo "Acquire::http::Pipeline-Depth \"0\";" > /etc/apt/apt.conf.d/99nopipelining && \
    apt-get clean && \
    apt-get update && \
    apt-get install -y netcat-traditional && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

COPY requirements.txt .

# 设置pip镜像源为阿里云
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && \
    pip config set install.trusted-host mirrors.aliyun.com && \
    pip install --no-cache-dir -r requirements.txt gunicorn gevent

# 创建必要的目录
RUN mkdir -p /app/logs /app/static

# 复制启动脚本并设置权限
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# 复制所有代码到容器
COPY . .

EXPOSE 8000

# 默认启动web服务
CMD ["/app/entrypoint.sh", "web"]