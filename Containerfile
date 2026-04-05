# ShiftClaw — OpenClaw on Red Hat UBI 10 + Node.js 24
# NOT based on Debian or Ubuntu — UBI 10 only.
#
# Build:
#   podman build -t shiftclaw:local .
#   podman build --build-arg OPENCLAW_VERSION=2026.4.2 -t shiftclaw:local .
#
# Multi-stage:
#   builder  — full UBI 10 Node.js image; npm install + cache stay here.
#   runtime  — minimal UBI 10 Node.js image; only node_modules copied in.
#
# UBI 10 nodejs-24-minimal ships user 1001 (home /opt/app-root/src, gid 0).
# OpenShift SCC (restricted) overrides UID at runtime; gid 0 ensures PVC access.

ARG OPENCLAW_VERSION=2026.4.2

# ---------------------------------------------------------------------------
# Stage 1 — builder
# ---------------------------------------------------------------------------
FROM registry.access.redhat.com/ubi10/nodejs-24:latest AS builder

ARG OPENCLAW_VERSION

WORKDIR /opt/app-root/src

USER 0
RUN npm install "openclaw@${OPENCLAW_VERSION}" \
        --omit=dev \
        --no-audit \
        --no-fund \
    && npm cache clean --force

# ---------------------------------------------------------------------------
# Stage 2 — runtime
# ---------------------------------------------------------------------------
FROM registry.access.redhat.com/ubi10/nodejs-24-minimal:latest AS runtime

ARG OPENCLAW_VERSION

LABEL org.opencontainers.image.title="ShiftClaw" \
      org.opencontainers.image.description="OpenClaw autonomous AI agent — UBI 10 + Node.js 24" \
      org.opencontainers.image.version="${OPENCLAW_VERSION}" \
      org.opencontainers.image.source="https://github.com/openclaw/openclaw" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="registry.access.redhat.com/ubi10/nodejs-24-minimal"

WORKDIR /opt/app-root/src

COPY --from=builder --chown=1001:0 /opt/app-root/src/node_modules ./node_modules

USER 0
RUN mkdir -p /var/lib/openclaw \
    && chown 1001:0 /var/lib/openclaw \
    && chmod g=u /var/lib/openclaw

USER 1001

ENV OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    # XDG_CONFIG_HOME tells openclaw where to store its state (official pattern from Hetzner docs).
    XDG_CONFIG_HOME=/var/lib/openclaw \
    OPENCLAW_CONFIG_PATH=/var/lib/openclaw/openclaw.json \
    NODE_ENV=production \
    NPM_CONFIG_CACHE=/tmp/.npm \
    # HOME must be writable; with readOnlyRootFilesystem the default /opt/app-root/src is read-only.
    HOME=/var/lib/openclaw \
    PATH="/opt/app-root/src/node_modules/.bin:$PATH"

EXPOSE 18789

ENTRYPOINT ["openclaw", "gateway", "--allow-unconfigured"]
