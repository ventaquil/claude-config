# Docker

Correctness + smallest image > any rule here; comment deviations.

## Multi-Stage Builds

- Builder stage (full toolchain) + minimal runtime stage. Never ship compiler/build deps to runtime.
- Static binaries (Go, Rust w/ musl): runtime = `scratch` or `distroless/static`. Needs libc/shell: `distroless` (glibc) or `alpine`.
- Copy only build artifact + runtime assets from builder into final stage:

```dockerfile
FROM rust:1-slim AS builder
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release

FROM gcr.io/distroless/cc-debian12
COPY --from=builder /src/target/release/app /app
USER nonroot
ENTRYPOINT ["/app"]
```

## Base Images

- Pin exact tag, digest preferred for reproducible/security-sensitive builds: `image:1.2.3@sha256:...`.
- Never `:latest` — untraceable, breaks reproducibility, breaks cache.
- Prefer official/minimal variants (`-slim`, `-alpine`, `distroless`) over full OS images.

## User & Process

- Final stage: non-root `USER` (numeric UID preferred, no `/etc/passwd` dependency in scratch/distroless).
- One process per container. Sidecar/supervisor patterns = separate containers, not `supervisord` inside one.
- `HEALTHCHECK` when service exposes a probe endpoint/command; omit if none exists (no fake check).

## Layers & Cache

- Order: least-changing first. Deps manifest (`package.json`, `Cargo.toml`, `go.mod`) + install → then source copy.
- Reordering source before deps invalidates cache every build — biggest CI time waster.
- `COPY` over `ADD` — `ADD` auto-extracts/fetches URLs, surprising side effects. `ADD` only for its extract feature, deliberately.
- Combine related `RUN` steps to cut layers or use bind cache mounts (`RUN --mount=type=cache`) for package managers.

## .dockerignore

- Required, every project. Exclude `.git`, `node_modules`/`target`/`vendor`, secrets, local env files, docs.
- Missing `.dockerignore` = slow/huge build context, risk of leaking secrets into layers.

## Compose

- Explicit image tags (`image: app:1.2.3`), never bare `latest` or untagged.
- No `network_mode: host` unless justified in comment (perf/hardware access) — breaks isolation, port mapping.
- Named volumes over bind mounts for persistent data unless host path is the point.
- Secrets via `secrets:`/env-file, never hardcoded in `environment:` or committed compose file.

## Checklist

- [ ] Multi-stage: builder deps absent from final image
- [ ] Base image pinned tag (+digest if reproducible/security-sensitive), no `:latest`
- [ ] Final stage runs as non-root `USER`
- [ ] `.dockerignore` present, excludes `.git`/build artifacts/secrets
- [ ] Deps copied+installed before source (cache-friendly layer order)
- [ ] `COPY` used unless `ADD` extract/fetch behavior deliberately needed
- [ ] `HEALTHCHECK` present if service exposes a probe
- [ ] Compose: explicit tags, no unjustified `network_mode: host`, secrets not hardcoded
