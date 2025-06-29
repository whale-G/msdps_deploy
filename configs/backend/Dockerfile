# 使用Python 3.10作为基础镜像
FROM python:3.10

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置工作目录
WORKDIR /app

COPY requirements.txt .

# 设置pip镜像源
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip install --no-cache-dir -r requirements.txt gunicorn gevent

# 创建必要的目录
RUN mkdir -p /app/logs /app/static

# 创建启动脚本
COPY <<EOF /app/entrypoint.sh
#!/bin/bash
case "\$1" in
    "web")
        exec gunicorn MSDPT_BE.wsgi:application \\
            --bind 0.0.0.0:8000 \\
            --workers 4 \\
            --worker-class gevent \\
            --timeout 120 \\
            --access-logfile /app/logs/gunicorn-access.log \\
            --error-logfile /app/logs/gunicorn-error.log
        ;;
    "scheduler")
        exec python manage.py run_scheduler
        ;;
    "celery")
        exec celery -A MSDPT_BE worker -l info
        ;;
    *)
        echo "Unknown command: \$1"
        exit 1
        ;;
esac
EOF

# 设置脚本权限
RUN chmod +x /app/entrypoint.sh

# 复制所有代码到容器
COPY . .

EXPOSE 8000

# 默认启动web服务
CMD ["/app/entrypoint.sh", "web"]