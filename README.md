# ShiftClaw

<p align="center">
  <img src="shiftclaw.png" alt="ShiftClaw" width="400">
</p>

> OpenClaw deployment for OpenShift: UBI 10 · Node.js 24 · OpenRouter · Telegram

[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026.4.2-orange)](https://github.com/openclaw/openclaw)
[![UBI 10](https://img.shields.io/badge/Red%20Hat%20UBI-10-EE0000?logo=redhat&logoColor=white)](https://catalog.redhat.com/software/containers/ubi10/nodejs-24-minimal)
[![Node.js](https://img.shields.io/badge/Node.js-24-5FA04E?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![OpenShift](https://img.shields.io/badge/OpenShift-compatible-EE0000?logo=redhatopenshift&logoColor=white)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

This repository contains everything needed to run [OpenClaw](https://github.com/openclaw/openclaw) as a Pod on an OpenShift/OKD cluster. The custom container image is built on **Red Hat UBI 10 + Node.js 24** (not Debian, not Ubuntu), hardened by default, and published to GHCR via GitHub Actions.

The deployment is managed through Telegram — no Ingress or Route is needed.

---

## Prerequisites

- `oc` configured against your cluster
- An [OpenRouter](https://openrouter.ai) API key
- A Telegram bot token from [@BotFather](https://t.me/BotFather)
- A GitHub account to push the container image to GHCR

---

## Deploy

### 1 — Build and push the image

Push to `main` (or tag a release) and GitHub Actions will build the image and publish it to `ghcr.io/rarguello/shiftclaw`. No manual `podman build` needed.

Then update the image reference in `manifests/statefulset.yaml`:

```yaml
image: ghcr.io/rarguello/shiftclaw:2026.4.2
```

### 2 — Create the Secret

Never commit real credentials. Create a local `.env` file (already in `.gitignore`):

```
OPENROUTER_API_KEY=sk-or-...
TELEGRAM_BOT_TOKEN=123456:ABC-...
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
```

Apply it to the cluster:

```bash
oc create secret generic shiftclaw --from-env-file=.env --namespace=shiftclaw
```

### 3 — Apply the manifests

```bash
oc apply -f manifests/
```

This creates the namespace, ServiceAccount, ConfigMap, StatefulSet (with its PVC), NetworkPolicy, PodDisruptionBudget, and Service in one shot.

### 4 — Verify

```bash
oc get pods -n shiftclaw -w
oc logs -l app.kubernetes.io/name=shiftclaw -n shiftclaw -f
```

### 5 — Approve the Telegram bot

On first start, OpenClaw requires manual approval of the Telegram channel pairing. Open a shell into the running pod and run:

```bash
oc exec -it shiftclaw-0 -n shiftclaw -- sh
openclaw pairing approve telegram <PAIRING_CODE>
```

The pairing code appears in the pod logs. Once approved the bot starts responding and the approval is persisted on the PVC — it does not need to be repeated on restart.

---

## Access

ShiftClaw is managed through Telegram — just talk to your bot. No Route or Ingress is required.

If you need local access to the WebSocket gateway (port 18789):

```bash
oc port-forward pod/shiftclaw-0 18789:18789 -n shiftclaw
```

---

## Configuration

| File | Purpose |
|------|---------|
| `config/openclaw.json` | Non-sensitive runtime config — model, channels, agent defaults |
| `manifests/secret.yaml.template` | Documents the expected Secret structure |
| `manifests/serviceaccount.yaml` | Dedicated ServiceAccount (no default SA token mounted) |
| `manifests/networkpolicy.yaml` | Default-deny ingress; egress limited to DNS + HTTPS only |
| `manifests/poddisruptionbudget.yaml` | Signals voluntary-disruption intent to the scheduler |
| `manifests/statefulset.yaml` | StatefulSet — resource limits, probes, security context, PVC template |
| `.github/workflows/build.yaml` | OpenClaw version pin and image build settings |

Edit `config/openclaw.json` to change the model, enable/disable channels, or tune agent parameters.

The config is seeded from the ConfigMap **only on first start** — OpenClaw edits its own config at runtime and those changes are preserved across restarts. To apply a ConfigMap change to a running deployment, delete the live config from the PVC so the init container re-seeds it on next start:

```bash
# 1 — Update the ConfigMap
oc create configmap shiftclaw-config \
  --from-file=openclaw.json=config/openclaw.json \
  --namespace=shiftclaw \
  --dry-run=client -o yaml | oc apply -f -

# 2 — Delete the live config so the init container re-seeds it
oc exec shiftclaw-0 -n shiftclaw -- rm /var/lib/openclaw/openclaw.json

# 3 — Restart
oc rollout restart statefulset/shiftclaw -n shiftclaw
```

---

## Upgrading OpenClaw

1. Update `OPENCLAW_VERSION` in `.github/workflows/build.yaml`
2. Update the `image:` tag in `manifests/statefulset.yaml`
3. Push — CI builds and publishes the new image automatically
4. `oc apply -f manifests/statefulset.yaml` (or `oc apply -k manifests/`)

---

## Security

The container image and Pod spec follow a secure-by-default posture:

- Non-root process (`runAsNonRoot: true`) — OpenShift SCC assigns the UID
- Read-only root filesystem (`readOnlyRootFilesystem: true`)
- All Linux capabilities dropped (`capabilities: drop: ALL`)
- Default seccomp profile (`seccompProfile: RuntimeDefault`)
- No privilege escalation (`allowPrivilegeEscalation: false`)
- Dedicated ServiceAccount with no token mounted (`automountServiceAccountToken: false`)
- NetworkPolicy: default-deny ingress; egress limited to DNS (53) + HTTPS (443)
- Secrets never baked into the image — injected at runtime via K8s Secret
- Every image build is scanned with Trivy; CRITICAL CVEs fail the pipeline
- SBOM and provenance attestations generated on every push

---

## License

MIT — same as [OpenClaw upstream](https://github.com/openclaw/openclaw).
Red Hat, OpenShift, and UBI are trademarks of Red Hat, Inc.
