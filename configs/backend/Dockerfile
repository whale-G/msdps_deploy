# 使用Python 3.10作为基础镜像
FROM python:3.10

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装netcat工具
RUN apt-get update && apt-get install -y netcat-traditional && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

COPY requirements.txt .

# 设置pip镜像源
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
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