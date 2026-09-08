# ============================================================
# Stage 1: Python dependency builder
# ============================================================
FROM python:3.12-slim-trixie AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        libffi-dev \
        libssl-dev; \
    python -m venv "${VIRTUAL_ENV}"; \
    python -m pip install --upgrade pip setuptools wheel; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY ops/sql-admin/requirements.txt ./requirements.txt

RUN pip install --no-cache-dir -r requirements.txt


# ============================================================
# Stage 2: Runtime
# ============================================================
FROM python:3.12-slim-trixie AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PATH="/opt/venv/bin:$PATH"

# ------------------------------------------------------------
# Microsoft repository + SQL tools + RDS CA certificates
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg; \
    mkdir -p /usr/share/keyrings; \
    curl -fsSL \
        https://packages.microsoft.com/keys/microsoft.asc \
        -o /tmp/microsoft.asc; \
    gpg --dearmor \
        -o /usr/share/keyrings/microsoft-prod.gpg \
        /tmp/microsoft.asc; \
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/repos/microsoft-debian-trixie-prod trixie main' \
        > /etc/apt/sources.list.d/microsoft-prod.list; \
    apt-get update; \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        mssql-tools18 \
        msodbcsql18; \
    curl -fsSL \
        https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
        -o /tmp/rds-bundle.pem; \
    awk '/BEGIN CERTIFICATE/ {i++} {print > ("/usr/local/share/ca-certificates/rds-" i ".crt")}' \
        /tmp/rds-bundle.pem; \
    update-ca-certificates; \
    apt-get purge -y --auto-remove \
        curl \
        gnupg; \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/*

# ------------------------------------------------------------
# Non-root runtime user
# ------------------------------------------------------------
RUN set -eux; \
    groupadd \
        --gid 10001 \
        app; \
    useradd \
        --uid 10001 \
        --gid 10001 \
        --no-create-home \
        --shell /usr/sbin/nologin \
        app

# ------------------------------------------------------------
# Application
# ------------------------------------------------------------
WORKDIR /app

# Copy pre-built Python virtual environment
COPY --from=builder /opt/venv /opt/venv

COPY --chown=10001:10001 \
    scripts/database.py \
    ./database.py

USER 10001:10001

# One-shot job; exit code determines success/failure.
HEALTHCHECK NONE

ENTRYPOINT ["python", "/app/database.py"]

CMD ["provision"]
