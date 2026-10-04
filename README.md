# Aegra container image

Multi-arch (`amd64`, `arm64`), signed container images for [Aegra](https://github.com/aegra/aegra), the open-source, self-hosted alternative to LangGraph Platform.

> Community-maintained by **upstreamyard**. This is not an official Aegra image. Aegra is © its authors and licensed under Apache-2.0 (license text in `/licenses/aegra/LICENSE` inside the image).

| Registry | Image |
|---|---|
| Docker Hub | `upstreamyard/aegra` |
| GitHub Container Registry | `ghcr.io/upstreamyard/aegra` |

**Tags:** `latest`, `<major>.<minor>` (e.g. `0.10`), `<version>` (e.g. `0.10.8`, matching the [upstream releases](https://github.com/aegra/aegra/releases)). New upstream releases are built automatically within 24 hours.

## Quick start

Aegra needs PostgreSQL (with pgvector). Redis is optional and only needed when you run several replicas.

```bash
curl -O https://raw.githubusercontent.com/upstreamyard/aegra/main/docker-compose.yml
export OPENAI_API_KEY=sk-...
docker compose up -d
curl http://localhost:2026/health
```

Or with plain `docker run`:

```bash
docker run -d -p 2026:2026 \
  -e DATABASE_URL=postgresql://user:password@your-postgres:5432/aegra \
  -e OPENAI_API_KEY=sk-... \
  upstreamyard/aegra:latest
```

Point any LangGraph SDK client at `http://localhost:2026`.

## Running your own agents

The image ships with Aegra's example graphs and `aegra.json` at `/app`. To serve your own graphs, mount your config and code and set `AEGRA_CONFIG`:

```bash
docker run -d -p 2026:2026 \
  -e DATABASE_URL=postgresql://user:password@your-postgres:5432/aegra \
  -e AEGRA_CONFIG=/agents/aegra.json \
  -v ./my-agents:/agents:ro \
  upstreamyard/aegra:latest
```

If your graphs need extra Python packages, build a thin image on top:

```dockerfile
FROM upstreamyard/aegra:0.10
USER root
RUN pip install --no-cache-dir langchain-anthropic
USER 10001:10001
COPY my-agents/ /agents/
ENV AEGRA_CONFIG=/agents/aegra.json
```

## Configuration

All of Aegra's settings are environment variables. See the [upstream `.env.example`](https://github.com/aegra/aegra/blob/main/.env.example) for the full list. The most important ones:

| Variable | Default in image | Notes |
|---|---|---|
| `DATABASE_URL` | – | `postgresql://user:pass@host:5432/db` (or set `POSTGRES_HOST`, `POSTGRES_USER`, …) |
| `AEGRA_CONFIG` | `/app/aegra.json` | Path to your graph config |
| `PORT` / `HOST` | `2026` / `0.0.0.0` | |
| `AUTH_TYPE` | `noop` | Set to `custom` for real auth in production |
| `RUN_MIGRATIONS_ON_STARTUP` | `true` | Set `false` for multi-replica deployments and run `aegra db upgrade` as a one-off job |
| `REDIS_BROKER_ENABLED` / `REDIS_URL` | `false` | Needed for multiple replicas (shared streaming and job queue) |
| `ENV_MODE` | `PRODUCTION` | JSON logs |
| `ENABLE_PROMETHEUS_METRICS` | `false` | Exposes `/metrics` |

## Kubernetes

For more than one replica:

1. Run migrations once per release as a Job: `command: ["aegra", "db", "upgrade"]`.
2. Set `RUN_MIGRATIONS_ON_STARTUP=false`, `REDIS_BROKER_ENABLED=true` and `REDIS_URL` on the Deployment.
3. Use `/health` for both readiness and liveness probes.

The container runs as non-root UID `10001` and is compatible with `runAsNonRoot: true`.

## Verifying images

Images are signed keylessly with [cosign](https://github.com/sigstore/cosign) and include an SBOM and SLSA provenance:

```bash
cosign verify upstreamyard/aegra:latest \
  --certificate-identity-regexp '^https://github.com/upstreamyard/aegra/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

docker buildx imagetools inspect upstreamyard/aegra:latest --format '{{ json .SBOM }}'
```

## How it's built

[`.github/workflows/build.yml`](.github/workflows/build.yml) checks out the upstream release tag and builds [`Dockerfile`](Dockerfile). Before publishing, it starts the image against a real PostgreSQL and waits for `/health` to pass. Everything is public and reproducible.

Differences from upstream's `deployments/docker/Dockerfile`: the `aegra` CLI is installed (so the default `aegra serve` command works), `tini` runs as PID 1, there's a built-in `HEALTHCHECK`, the UID is fixed, and builds are multi-arch.

## Support

Issues with the image: [open an issue here](https://github.com/upstreamyard/aegra/issues). Issues with Aegra itself: [upstream](https://github.com/aegra/aegra/issues).
