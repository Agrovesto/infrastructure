# Build this image in a trusted application/image pipeline, scan it, then promote
# by digest. The rolling Python minor tag receives security fixes; pin its digest
# in your image supply-chain process and let Dependabot propose reviewed updates.
FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# A signed Microsoft package repository (not curl | sh). RDS CA certificates are
# installed in the OS trust store so production sqlcmd never needs -C.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o /tmp/microsoft.asc \
    && gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg /tmp/microsoft.asc \
    && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main' > /etc/apt/sources.list.d/microsoft-prod.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends mssql-tools18 msodbcsql18 \
    && curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /tmp/rds-bundle.pem \
    && awk '/BEGIN CERTIFICATE/ {i++} {print > ("/usr/local/share/ca-certificates/rds-" i ".crt")}' /tmp/rds-bundle.pem \
    && update-ca-certificates \
    && apt-get purge -y --auto-remove curl gnupg \
    && rm -rf /var/lib/apt/lists/* /tmp/* \
    && groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY ops/sql-admin/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=10001:10001 scripts/database.py ./database.py
USER 10001:10001
# This is a one-shot job: its exit code, not a daemon HTTP healthcheck, is the gate.
HEALTHCHECK NONE
ENTRYPOINT ["python", "/app/database.py"]
CMD ["provision"]
