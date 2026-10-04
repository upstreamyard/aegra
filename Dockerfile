# Container image for Aegra (https://github.com/aegra/aegra)
# Maintained by upstreamyard. Builds the upstream source checked out into ./upstream
# at the release tag selected by CI.

ARG PY_VERSION=3.12
FROM python:${PY_VERSION}-slim-bookworm AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on

WORKDIR /app

RUN addgroup --system --gid 10001 app && adduser --system --uid 10001 --ingroup app app

# -----------------------------
# Builder
# -----------------------------
FROM base AS builder

COPY --from=ghcr.io/astral-sh/uv:0.10.0 /uv /bin/uv

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY upstream/ ./

# Third-party dependencies from the workspace lockfile (same set as upstream's
# own Dockerfile, which includes the deps the bundled example agents need),
# then the two workspace packages: the API server and the `aegra` CLI.
# Upstream's image omits the CLI, so its default `aegra serve` command fails.
RUN uv export --frozen --all-packages --no-emit-workspace --format=requirements-txt > requirements.txt && \
    uv pip install --system --compile-bytecode -r requirements.txt && \
    uv pip install --system --compile-bytecode --no-deps ./libs/aegra-api ./libs/aegra-cli

# -----------------------------
# Runtime
# -----------------------------
FROM base AS final

ARG PY_VERSION
ARG AEGRA_VERSION=unknown

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libpq5 \
    tini \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python${PY_VERSION}/site-packages/ /usr/local/lib/python${PY_VERSION}/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

COPY upstream/libs/aegra-api/alembic.ini ./alembic.ini
COPY upstream/libs/aegra-api/alembic/ ./alembic/
COPY upstream/aegra.json ./aegra.json
COPY upstream/examples/ ./examples/
COPY upstream/LICENSE /licenses/aegra/LICENSE

ENV HOST=0.0.0.0 \
    PORT=2026 \
    AEGRA_CONFIG=/app/aegra.json \
    ENV_MODE=PRODUCTION

LABEL org.opencontainers.image.title="aegra" \
      org.opencontainers.image.description="Aegra - self-hosted, open-source alternative to LangGraph Platform. Community image by upstreamyard." \
      org.opencontainers.image.version="${AEGRA_VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="upstreamyard" \
      org.opencontainers.image.url="https://github.com/upstreamyard/aegra" \
      org.opencontainers.image.documentation="https://github.com/upstreamyard/aegra#readme"

EXPOSE 2026

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf "http://localhost:${PORT}/health" || exit 1

USER 10001:10001

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["aegra", "serve"]
