#!/bin/bash

# 等待MySQL服务就绪
echo "Waiting for MySQL to be ready..."
while ! nc -z mysql 3306; do
    sleep 1
done
echo "MySQL is ready"

# 只在web服务时执行初始化步骤
if [ "$1" = "web" ]; then
    # 执行数据库迁移
    echo "Running database migrations..."
    python manage.py makemigrations
    python manage.py migrate

    # 创建超级用户（如果不存在）
    echo "Creating/updating superuser..."
    python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(user_name='$ADMIN_ACCOUNT').exists():
    User.objects.create_superuser('$ADMIN_ACCOUNT', '', '$ADMIN_INITIAL_PASSWORD')
EOF
else
    echo "Skipping database initialization for non-web service"
fi

case "$1" in
    "web")
        exec gunicorn MSDPT_BE.wsgi:application \
            --bind 0.0.0.0:8000 \
            --workers 4 \
            --worker-class gevent \
            --timeout 120 \
            --access-logfile /app/logs/gunicorn-access.log \
            --error-logfile /app/logs/gunicorn-error.log
        ;;
    "scheduler")
        exec python manage.py run_scheduler
        ;;
    "celery")
        exec celery -A MSDPT_BE worker -l info
        ;;
    *)
        echo "Unknown command: $1"
        exit 1
        ;;
esac