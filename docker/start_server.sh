#!/bin/bash -e

show_first_last_3() {
    local str="$@"
    echo "${str:0:3}...${str: -3}"
}

(
    echo "✔︎ GOOGLE_SEARCH_ENGINE_ID=$GOOGLE_SEARCH_ENGINE_ID"
    test -n "$GOOGLE_SEARCH_API_KEY" && \
        echo "✅ GOOGLE_SEARCH_API_KEY=$(show_first_last_3 $GOOGLE_SEARCH_API_KEY)" || \
        echo "❓ GOOGLE_SEARCH_API_KEY"
    test -n "$GOOGLE_SEARCH_ENGINE_ID" && \
        echo "✅ GOOGLE_SEARCH_ENGINE_ID=$(show_first_last_3 $GOOGLE_SEARCH_ENGINE_ID)" || \
        echo "❓ GOOGLE_SEARCH_ENGINE_ID"
    test -n "$GROQ_API_KEY" && \
        echo "✅ GROQ_API_KEY=$(show_first_last_3 $GROQ_API_KEY)" || \
        echo "❓ GROQ_API_KEY"
    echo "✅ DOMAINS_ALLOW=$DOMAINS_ALLOW"
) | tee /app/env_inspect.txt

cd /app/backend

/app/groq_test.py

log_dir=/var/log/app
mkdir -p $log_dir
backend_log_file=$log_dir/backend.log

gunicorn \
    --bind 0.0.0.0:30001 \
    --daemon \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --max-requests 1000 \
    --max-requests-jitter 50 \
    --pid /tmp/gunicorn.pid \
    --log-file $backend_log_file \
    fastapi_app:app

echo "Follow backgrounded Gunicorn + UvicornWorker Python backend app log at $backend_log_file"

nginx -g "daemon off;"
