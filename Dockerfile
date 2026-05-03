# Purpose: Build a small FoundryVTT runtime image for Unraid and similar Docker hosts.
# Input/Output: The build copies helper scripts plus Node 22 and Node 24 runtimes; the running container downloads the official Foundry Node.js archive on demand.
# Invariants: No proprietary Foundry application files are baked into the image. User data lives outside the app directory.
# Debug: Start the container with LOG_LEVEL=debug and inspect `docker logs <container-name>`.

FROM node:22-bookworm-slim AS node22

FROM node:24-bookworm-slim AS node24

FROM debian:bookworm-slim

# Why this exists: The runtime needs curl and unzip to fetch the official archive,
# gosu to drop privileges after fixing permissions, and tini for clean signal handling.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gosu tini unzip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node22 /usr/local/ /opt/node22/
COPY --from=node24 /usr/local/ /opt/node24/

ENV APP_HOME=/opt/foundryvtt \
    FOUNDRY_ROOT=/data/foundryvtt \
    FOUNDRY_APP_PATH=/data/foundryvtt/app \
    FOUNDRY_DATA_PATH=/data/foundryvtt/userdata \
    FOUNDRY_CACHE_PATH=/data/foundryvtt/cache \
    FOUNDRY_COMPATIBILITY_MODE=auto \
    FOUNDRY_PORT=30000 \
    FOUNDRY_UPNP=false \
    FOUNDRY_PROXY_SSL=false \
    FOUNDRY_DISABLE_UPDATES=false \
    FOUNDRY_DISABLE_IP_DISCOVERY=false \
    FOUNDRY_FORCE_REINSTALL=false \
    FOUNDRY_HEALTHCHECK_SCHEME=http \
    HOST_NODE_BIN=/opt/node24/bin/node \
    FOUNDRY_NODE22_BIN=/opt/node22/bin/node \
    FOUNDRY_NODE24_BIN=/opt/node24/bin/node \
    PUID=99 \
    PGID=100 \
    LOG_LEVEL=info \
    PATH=/opt/node24/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR ${APP_HOME}

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY docker/detect-foundry-major.mjs /usr/local/lib/foundry/detect-foundry-major.mjs
COPY docker/render-options.mjs /usr/local/lib/foundry/render-options.mjs

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

EXPOSE 30000/tcp

VOLUME ["/data/foundryvtt"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=5 CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
