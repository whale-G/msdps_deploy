#!/bin/bash
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