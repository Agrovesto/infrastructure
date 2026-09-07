# Sample API image that satisfies the Agrovesto platform contract:
#   - linux/amd64, non-root 10001, read-only root, listens on 0.0.0.0:8080
#   - unauthenticated GET /health
#   - reads DB_* from the environment (Compose env_file or ECS secrets)
#
# Replace the placeholder app with your real service. Keep the contract.
# Build: docker build --platform linux/amd64 -f apps/api/Dockerfile -t agrovesto/api:local .

FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app \
    && mkdir -p /app \
    && chown 10001:10001 /app

WORKDIR /app

# Minimal stdlib HTTP server so the stack is runnable without extra deps.
# Swap this for your real framework (ASP.NET, Node, Go, …) while keeping the contract.
COPY apps/api/server.py /app/server.py
RUN chown 10001:10001 /app/server.py

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')" || exit 1

CMD ["python", "/app/server.py"]
