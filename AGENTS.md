# AGENTS.md

Instructions for AI agents and coding assistants working with this repository or deploying the image it publishes.

## Image facts

| Key | Value |
|---|---|
| Image | `upstreamyard/aegra` (Docker Hub), `ghcr.io/upstreamyard/aegra` |
| Tags | `<version>` (e.g. `0.10.8`), `<major>.<minor>` (e.g. `0.10`), `latest` |
| Platforms | `linux/amd64`, `linux/arm64` |
| Port | `2026` (HTTP, LangGraph-compatible Agent Protocol API) |
| Liveness | `GET /live` (process up, no DB check) |
| Readiness | `GET /ready` (503 until PostgreSQL and LangGraph backends respond) |
| Full health | `GET /health` (JSON status per component, 503 if any is unhealthy) |
| API docs | `GET /docs` (Swagger UI), `GET /openapi.json` |
| Metrics | `GET /metrics` when `ENABLE_PROMETHEUS_METRICS=true` |
| User | non-root, UID/GID `10001` |
| Entrypoint | `tini --`, default command `aegra serve` |
| Required dependency | PostgreSQL (upstream tests with `pgvector/pgvector:pg18`; pgvector is only needed for semantic store search) |
| Optional dependency | Redis, required when running more than one replica |
| Config file | `AEGRA_CONFIG`, default `/app/aegra.json` (bundled example graphs) |
| Upstream | https://github.com/aegra/aegra (Apache-2.0) |

## Deploying the image

Rules that avoid the common failures:

- **Database:** set `DATABASE_URL=postgresql://USER:PASS@HOST:5432/DB`. URL-encode special characters in the password (`@` becomes `%40`), or set `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_DB` instead. `sslmode=require` is supported.
- **LLM keys:** the bundled example graphs use OpenAI. Set `OPENAI_API_KEY` or replace `AEGRA_CONFIG` with your own graphs.
- **Single replica:** nothing else needed. Migrations run automatically on startup.
- **More than one replica:** set `REDIS_BROKER_ENABLED=true`, `REDIS_URL=redis://HOST:6379/0` and `RUN_MIGRATIONS_ON_STARTUP=false`, then run `aegra db upgrade` once per release (Kubernetes Job or init container, same image).
- **Auth:** the default `AUTH_TYPE=noop` accepts every request. Never expose it publicly without putting auth in front or configuring `AUTH_TYPE=custom`.
- **Own graphs:** mount a directory with `aegra.json` and your graph code, then set `AEGRA_CONFIG` to that file. Extra Python packages need a derived image (see README).

Ready-to-use manifests:

- Docker Compose: [`docker-compose.yml`](docker-compose.yml)
- Kubernetes: [`examples/kubernetes/aegra.yaml`](examples/kubernetes/aegra.yaml) (Secret, migration Job, Deployment, Service)

Verify a deployment:

```bash
curl -sf http://HOST:2026/ready && curl -s http://HOST:2026/health
```

Database migration commands, run inside the image:

```bash
aegra db upgrade      # apply all migrations
aegra db current      # show the current revision
aegra db history      # list revisions
```

## Working on this repository

Layout:

- `Dockerfile`: builds the upstream source, which CI checks out into `./upstream/` (git-ignored)
- `.github/workflows/build.yml`: resolves the upstream version, builds, smoke-tests against PostgreSQL, then pushes, signs and syncs the Docker Hub README
- `examples/`: deployment manifests, which must keep working with the published image

Build and test locally:

```bash
git clone --depth 1 --branch v0.10.8 https://github.com/aegra/aegra.git upstream
docker build -t aegra:dev --build-arg AEGRA_VERSION=0.10.8 .
docker compose up -d   # edit the image in docker-compose.yml to aegra:dev first
curl -sf http://localhost:2026/ready
```

Rules:

- Never push to `main`. Create a branch and open a pull request into `main`.
- Do not modify upstream source. Fix packaging problems in the `Dockerfile` and report upstream bugs at https://github.com/aegra/aegra/issues.
- Keep the image non-root with UID `10001`, and keep `HEALTHCHECK` and the OCI labels.
- When `/ready`, `/live`, the port or the required environment variables change upstream, update `README.md`, this file, `llms.txt` and `examples/` in the same pull request.
- The workflow must pass `actionlint` (`docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:latest`).
- `README.md` is also the Docker Hub description, so keep it under 25,000 characters.
