FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

ARG FRONTEND_BUILD_DIR=frontend/build-prod

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=never

COPY --from=nginx:1.29.0-bookworm /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx:1.29.0-bookworm /etc/nginx/ /etc/nginx/
COPY --from=nginx:1.29.0-bookworm /var/log/nginx/ /var/log/nginx/

RUN groupadd -g 101 nginx && \
    useradd -r -u 101 -g nginx -s /sbin/nologin -d /var/cache/nginx -M nginx && \
    mkdir -p /var/cache/nginx /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx && \
    grep PRETTY_NAME /etc/os-release && \
    nginx -v && \
    python -V && \
    echo $(uv --version)

WORKDIR /app

COPY $FRONTEND_BUILD_DIR /app/frontend
COPY docker/nginx.conf /etc/nginx/nginx.conf
RUN ls -ld /app/frontend/* && \
    test -f /app/frontend/index.html && \
    cat /etc/nginx/nginx.conf

COPY backend backend
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --python /usr/local/bin/python -r /app/backend/requirements.txt && \
    ls -ald /app/backend/* && \
    gunicorn --version && \
    python -c 'import groq'

COPY docker/*.sh docker/*.py /app/

EXPOSE 30000

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/start_server.sh"]
