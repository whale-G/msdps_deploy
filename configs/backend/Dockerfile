# 使用Python 3.9作为基础镜像
FROM python:3.9

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone

# 设置工作目录
WORKDIR /app

COPY requirements.txt .

# 设置pip镜像源
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip install --no-cache-dir -r requirements.txt gunicorn gevent

# 创建必要的目录
RUN mkdir -p /app/logs /app/static

# 复制所有代码到容器
COPY . .

EXPOSE 8000

# 使用gunicorn启动
CMD ["gunicorn", "MSDPT_BE.wsgi:application", "--bind", "0.0.0.0:8000", 
     "--workers", "4", "--worker-class", "gevent", "--timeout", "120", 
     "--access-logfile", "/app/logs/gunicorn-access.log", 
     "--error-logfile", "/app/logs/gunicorn-error.log"]