FROM python:3.9

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone

WORKDIR /app

# 设置pip镜像源
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn gevent

# 创建必要的目录
RUN mkdir -p /app/logs /app/static

COPY . .

# 构建环境变量文件
RUN echo "\
# 通用环境变量配置\n\

# Internationalization\n\
# https://docs.djangoproject.com/en/5.1/topics/i18n/\n\
USE_I18N = True\n\
USE_TZ = True\n\

# 时区设置\n\
TIME_ZONE=Asia/Shanghai\n\
LANGUAGE_CODE=zh-hans\n\

# 文件上传大小限制（按需调整）\n\
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024  # 10MB\n\
FILE_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024  # 10MB\n\
" > .env

# 构建生产环境变量配置
RUN echo "\
# 基础环境变量配置\n\
DJANGO_ENV=production\n\
DEBUG=False\n\
ALLOWED_HOSTS=*\n\
SECRET_KEY=\${DJANGO_SECRET_KEY}\n\

# 数据库配置\n\
DB_HOST=db\n\
DB_PORT=3306\n\
DB_NAME=\${MYSQL_DATABASE}\n\
DB_USER=\${MYSQL_USER}\n\
DB_PASSWORD=\${MYSQL_PASSWORD}\n\

# Redis配置\n\
REDIS_HOST=redis\n\
REDIS_PORT=6379\n\
REDIS_PASSWORD=\${REDIS_PASSWORD}\n\
REDIS_DB=0\n\

# JWT配置\n\
JWT_ACCESS_MINUTES=60\n\
JWT_REFRESH_DAYS=2\n\

# Django配置\n\
ADMIN_ACCOUNT=\${DJANGO_SUPERUSER_USERNAME}\n\
ADMIN_INITIAL_PASSWORD=\${DJANGO_SUPERUSER_PASSWORD}\n\

# 安全设置\n\
SECURE_SSL_REDIRECT=False\n\
SESSION_COOKIE_SECURE=True\n\
CSRF_COOKIE_SECURE=True\n\
SECURE_BROWSER_XSS_FILTER=True\n\
SECURE_CONTENT_TYPE_NOSNIFF=True\n\
X_FRAME_OPTIONS=DENY\n\
" > .env.production

EXPOSE 8000

# 使用gunicorn启动
CMD ["gunicorn", "MSDPT_BE.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4", "--worker-class", "gevent", "--timeout", "120", "--access-logfile", "/app/logs/gunicorn-access.log", "--error-logfile", "/app/logs/gunicorn-error.log"]