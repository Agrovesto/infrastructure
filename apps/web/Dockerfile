# Sample web image for prod ECS (or local Compose).
# Static files on 0.0.0.0:8080, non-root 10001, read-only root friendly.
#
# Build: docker build --platform linux/amd64 -f apps/web/Dockerfile -t agrovesto/web:local .
# Dev frontends more often use Amplify static Hosting (ZIP via scripts/publish-amplify.sh).

FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app \
    && mkdir -p /app/public \
    && chown -R 10001:10001 /app

WORKDIR /app
COPY apps/web/public/ /app/public/
COPY apps/web/serve.py /app/serve.py
RUN chown -R 10001:10001 /app

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/')" || exit 1

CMD ["python", "/app/serve.py"]
