# vinOS Cloud — headless runtime for the same `.vinos/routines.yaml`

**Status:** draft (2026-07-25) · **Target:** v2.1.0 · **Companions:**
[vinos-routine-spec.md](vinos-routine-spec.md) ·
[vinos-routines-yaml-spec.md](vinos-routines-yaml-spec.md) ·
[ROADMAP.md](ROADMAP.md)

## 1. Positioning

vinOS Cloud is the **headless trim-down** of vinOS Desktop: the exact
same routine runtime, minus the Wayland stack, packaged for Docker,
systemd-nspawn, Kubernetes, and one-click VPS boot. Your agents don't
stop when your laptop closes.

Same substrate, two skins:

- **Desktop v2.0.x** — the founder writes and iterates a routine at
  their kitchen table. mako toasts, waybar widget, walker brief panel.
- **Cloud v2.1** — the same `.vinos/routines.yaml`, checked into the
  team repo, runs on a $5/mo Hetzner VPS or a shared Kubernetes cluster.
  Webhooks replace toasts; CronJobs replace user timers; a PVC replaces
  `~/.vinos/routines/state/`.

This is the founder → enterprise adoption arc: one engineer buys in on
their MacBook, the team commits routines to `main`, platform deploys the
Helm chart, IT signs off on the sandbox + audit story. Every step of
that arc uses the same runtime binary, the same spec, the same ledger
schema. No lift, no rewrite, no "well, in production we use…" split
brain. That is the whole product.

## 2. Architecture — three layers, one substrate

```
        +--------------------------------------------------+
        |  vinOS DESKTOP v2.0.x  (ships today)             |
        |  - Hyprland / waybar / walker / mako / plymouth  |
        |  - foot / greetd / themes / wallpapers           |
        |  - vinos-welcome first-boot flow                 |
        +---------------------+----------------------------+
                              |
                              |  same substrate
                              v
+---------------------------------------------------------------+
|  SHARED SUBSTRATE                                             |
|  - .vinos/routines.yaml            (project spec)             |
|  - libexec/vinos-routine-run.py    (runtime)                  |
|  - libexec/vinos-routine-load.py   (yaml → toml loader)       |
|  - libexec/vinos_routine_cron.py   (cron → OnCalendar/k8s)    |
|  - bin/vinos-routine  bin/vinos-brief  bin/vinos-ai           |
|  - Ollama HTTP client   +   SQLite ledger   +   bwrap sandbox |
+---------------------------------------------------------------+
                              ^
                              |  same substrate
                              |
        +---------------------+----------------------------+
        |  vinOS CLOUD v2.1  (new)                         |
        |  - Docker image  (ghcr.io/vinpatel/vinos-cloud)  |
        |  - systemd-nspawn tar for bare-metal ops         |
        |  - Helm chart    (helm install vinos/agents)     |
        |  - cloud-init one-clicks (Hetzner first)         |
        +--------------------------------------------------+
```

**Stripped for Cloud** — none of these ship in the image:

- Hyprland, waybar, walker, mako, plymouth, greetd
- foot, ghostty, alacritty, kitty (no TTY UI in the container)
- theme + wallpaper packs, `omarchy-theme-*`
- `vinos-welcome`, first-boot flow, ISO installer machinery

**Kept for Cloud** — the honest bill of materials:

- `python3.13`, `sqlite3`, `curl`, `git`, `bubblewrap`, `ca-certificates`
- `libexec/vinos-routine-run.py` + `vinos-routine-load.py` +
  `vinos_routine_cron.py`
- `bin/vinos-routine` (full command surface), `bin/vinos-brief`
- `bin/vinos-ai` in a **degraded** mode: `models`, `pull`, `run`, `serve`
  work if an Ollama binary is present; interactive `chat`/`code` return
  a clear "requires TTY — use SSH" message. See §4.
- Anthropic Python SDK (imported lazily; no import if `route=ollama`)

## 3. Ship targets

### 3.A Docker image — `ghcr.io/vinpatel/vinos-cloud:2.1`

- **Base:** Alpine 3.20. See §3.A.1 for why.
- **Uncompressed size target:** ~300 MB (Anthropic SDK + Python stdlib +
  bwrap + git + curl dominate; Ollama client is HTTP so no daemon).
  Compressed layer target: ~110 MB.
- **Contents:**
  - `python3.13` + `py3-anthropic` (or pip-installed at build)
  - `sqlite`, `curl`, `git`, `bubblewrap`, `ca-certificates`, `tzdata`
  - `/usr/lib/vinos/{vinos-routine-run.py, vinos-routine-load.py,
    vinos_routine_cron.py}`
  - `/usr/bin/{vinos-routine, vinos-brief, vinos-ai}`
- **Scheduling:** the image itself does **not** ship a cron daemon.
  Trigger is the caller's job:
  - Kubernetes CronJob (canonical, see §3.C)
  - systemd host timer that calls `docker run … vinos-routine run <name>`
  - `dcron`/`crond` in a sidecar for lift-and-shift ops shops
  This keeps the image single-purpose and the schedule declarative in
  the orchestrator that already owns your schedules.
- **Config surface:**
  - env vars (§5)
  - bind-mount `/etc/vinos/routines/` (system routines, read-only) or a
    `.vinos/routines.yaml` at `/etc/vinos/routines.yaml` — the entrypoint
    calls `vinos-routine load /etc/vinos/routines.yaml` on cold start if
    the file exists.
- **Secrets:**
  - `ANTHROPIC_API_KEY` via env (K8s Secret → `envFrom`)
  - optional `/root/.vinos/secrets/anthropic-key` for the file-based
    fallback path already supported by the runtime
- **State:** bind-mount `/var/lib/vinos` — holds
  `routines/state/ledger.db`, per-routine markdown outputs, and memory
  files. This is the one PVC / volume the operator has to size.
- **User:** `runAsNonRoot` — the image ships a `vinos:vinos` uid 1000
  and defaults its entrypoint to that user. Root-owned bwrap suid path
  is used if present; otherwise userns-bwrap. See §7.

#### 3.A.1 Base image decision — Alpine over minimal Arch

- **Alpine chosen.** Smaller (~80 MB base vs ~250 MB for `archlinux:base`),
  battle-tested musl toolchain, easier to `docker scan` cleanly, and the
  runtime is pure-Python + a handful of C tools — nothing that needs
  glibc-specific behavior.
- The one wrinkle is `bwrap` under musl — it works, but the suid-root
  path is uncommon on Alpine; we rely on userns bwrap (kernel ≥ 4.18
  with `kernel.unprivileged_userns_clone=1`, which is the default on
  every mainstream 2024+ K8s node). Documented in §7.
- ?? [needs decision] whether we also ship an `-arch` tag on the same
  version for shops with an Arch-only container policy. Cheap to add
  from the existing ISO packaging pipeline; skip unless someone asks.

### 3.B systemd-nspawn image — bare-metal ops shops

- Same **content** as the Docker image, exported as a `machinectl`-friendly
  directory tree plus a `vinos-cloud-2.1.tar.xz`.
- Install path: `sudo machinectl import-tar vinos-cloud-2.1.tar.xz
  vinos-cloud` → `systemctl start systemd-nspawn@vinos-cloud`.
- Ships a `/etc/systemd/nspawn/vinos-cloud.nspawn` with
  `PrivateUsers=pick`, `Bind=/var/lib/vinos:/var/lib/vinos`,
  `Environment=OLLAMA_URL=http://host:11434`, and no network by default
  (operator sets `Private=no` when they want egress).
- Scheduling: **host systemd timers** call `machinectl shell
  vinos-cloud /usr/bin/vinos-routine run <name>`. This is the natural
  target for shops that already run systemd and don't want a Docker
  daemon on the box.
- Not published as a first-class artifact in v2.1.0 — see §9. The tar
  is generated by the same Alpine build with an extra `nspawn` target.

### 3.C Kubernetes Helm chart — `helm install vinos-agents vinos/agents`

- Chart repo: `helm repo add vinos https://vinos.computer/helm`
- Chart layout: standard `templates/`, `values.yaml`, `Chart.yaml`. No
  custom operator, no CRDs. See §6 for the full values schema and a
  `helm template` sample.
- Resources emitted:
  - **N CronJobs** — one per routine, schedule translated from
    `[schedule].oncalendar`/`.cron` via `vinos_routine_cron.py` at
    template render time (`helm install` invokes a small go-templated
    helper; the actual translation still runs Python once per routine
    during chart build in CI, cached to a `translations.yaml`).
  - **1 PVC** — `vinos-state`, RWX preferred (shared ledger across
    CronJobs); RWO with per-routine subdir also supported.
  - **1 Secret** — `vinos-api-keys` (referenced by name via
    `anthropic.secretName`; not created by the chart unless
    `anthropic.createSecret=true` and a key is provided in values).
  - **0 or 1 Deployment** — the Ollama sidecar, if
    `ollama.enabled=true`. Ships a Service `vinos-ollama:11434`.
  - **1 ServiceAccount** + **1 Role** + **1 RoleBinding** —
    least-privilege: read own Secrets, no other permissions.
  - **1 NetworkPolicy** (if `networkPolicy.enabled=true`) — allows
    egress to `ollama` service only unless `anthropic.enabled=true`,
    which adds egress to `api.anthropic.com:443`.
- **Ollama sidecar posture:** default `ollama.enabled=false`. Rationale:
  most clusters already have a shared Ollama or an external LLM gateway;
  bundling a sidecar that defaults on would double GPU spend by
  surprise. When enabled it's a Deployment (not sidecar-per-job) so one
  model load serves N CronJobs — that's the value.
- **Honest promise:** the chart values map to `RoutineSet` **defaults**,
  not 1:1 to every field of every routine. Per-routine overrides come
  from the ConfigMap-mounted or git-cloned `routines.yaml` itself. This
  matches the `/for/platform/` page copy verbatim.

### 3.D Cloud-init one-clicks — founder-friendly VPS boot

Each target is one command; the script does: install docker, pull the
image, drop a systemd unit + timer, write `/etc/vinos/routines.yaml`
from a URL or inline block, start.

- **Hetzner Cloud** (v2.1.0 primary — cheapest EU/US, HN founder default):
  ```
  curl -fsSL https://vinos.computer/cloud/deploy/hetzner.sh | sh
  ```
  Bootstraps a `cx22` (2 vCPU / 4 GB / €5.83/mo) with cloud-init that
  pulls `ghcr.io/vinpatel/vinos-cloud:2.1`, creates a state volume,
  installs one systemd timer per routine. Requires `HCLOUD_TOKEN` env
  or interactive prompt.
- **DigitalOcean** — deferred to v2.1.x. Same script shape, `doctl`
  instead of `hcloud`.
- **Fly.io Machines** — deferred to v2.1.x. `fly machine run` with an
  attached volume; `[[schedules]]` in `fly.toml` for cron.
- **Google Cloud Run** — deferred to v2.1.x with a caveat: Cloud Run is
  HTTP-triggered, so we adapt cron→Cloud Scheduler jobs that POST to a
  `POST /run/<name>` endpoint on the container. That endpoint is itself
  deferred to v2.1.x (see §9), so Cloud Run naturally lands together.

The `hetzner.sh` script is the load-bearing MVP. The others are
progressive add-ons that don't gate v2.1.0.

## 4. Runtime differences — Desktop vs Cloud

| Feature | Desktop v2.0.x | Cloud v2.1 |
|---|---|---|
| Scheduler | systemd **user** timers (`vinos-routine@<name>.timer`) | K8s CronJob · systemd **host** timer · dcron sidecar |
| Notifications | mako toast + waybar module | webhook POST (Slack/Discord/email) + append to `/var/lib/vinos/routines/state/<name>/*.md` |
| Brief viewer | `vinos-brief` in walker panel | `vinos-brief` prints to stdout; optional HTTP endpoint (v2.1.x) |
| Interactive utilities | `vinos-fix`, `vinos-explain`, `vinos-commit`, `vinos-ai chat`, `vinos-ai code` — TTY-driven | Return `error: interactive utilities require a TTY. exec into the pod with 'kubectl exec -it' or SSH the host, then re-invoke.` |
| Ollama | local daemon, GPU-optional | remote HTTP URL via `OLLAMA_URL` (sidecar, external gateway, or host loopback) |
| Auth to Anthropic | `~/.vinos/secrets/anthropic-key` OR env | **env only** — no interactive prompt path is compiled in |
| Multi-user | single uid 1000 `vinos` user | K8s namespaces (cluster) OR systemd `DynamicUser=yes` per unit (single-node nspawn) |
| Ledger | `~/.vinos/routines/state/ledger.db` (per-user) | `/var/lib/vinos/ledger.db` on a shared PVC (cluster) or per-tenant PVC |
| Memory files | `~/.vinos/routines/state/<name>/memory.md` | `/var/lib/vinos/routines/state/<name>/memory.md` — same path shape under the container root |
| Sandbox | `bwrap` suid or userns | `bwrap` **userns only** (see §7) |
| First-boot flow | `vinos-welcome` guides enable/disable | none — routines are defined by the mounted YAML, activated by the CronJob existing |
| Update path | `pacman -Syu` | pull a new image tag; migrations are additive `ALTER TABLE` on ledger open (spec §runtime-ledger-columns) |

## 5. Config surface

**Env vars** (all targets accept these; K8s injects via env/envFrom):

```
# Provider auth
ANTHROPIC_API_KEY             required if any routine uses route=anthropic or route=auto
OLLAMA_URL                    default: http://localhost:11434
                              (K8s chart default: http://vinos-ollama:11434 when sidecar enabled)

# Routine paths
VINOS_ROUTINES_SYS            default: /etc/vinos/routines
VINOS_ROUTINES_USER           default: /var/lib/vinos/routines
VINOS_ROUTINES_STATE          default: /var/lib/vinos/routines/state
VINOS_LEDGER_DB               override for ledger path
                              default: $VINOS_ROUTINES_STATE/ledger.db

# Outputs
VINOS_WEBHOOK_URL             optional: POST routine results here (see §5.1)
VINOS_WEBHOOK_FORMAT          slack | discord | generic-json    (default: generic-json)
VINOS_AUDIT_LOG               default: /var/lib/vinos/audit.log

# Guardrails
VINOS_ESCALATION_CAP          override [agent.escalation].max_escalations_per_run
                              — process-wide safety net regardless of routine config
VINOS_MAX_DOLLARS_PER_DAY_GLOBAL   optional org-wide cap applied on top of per-routine caps
VINOS_NETWORK_MODE            local-only | allow-anthropic | allow-all   (default: allow-anthropic)

# Time
TZ                            standard; propagated to systemd/cron/schedulers
```

**Mount points** (canonical container paths):

```
/etc/vinos/routines/          ro   system routines (either single-file TOMLs
                                   OR a routines.yaml the entrypoint loads once)
/var/lib/vinos/               rw   ledger, state, memory files, audit log
/root/.vinos/secrets/         ro   optional file-based secret fallback
/etc/localtime                ro   optional; else TZ env wins
```

### 5.1 Webhook contract

`POST $VINOS_WEBHOOK_URL` on every routine run (success or failure).

Body when `VINOS_WEBHOOK_FORMAT=generic-json`:

```json
{
  "routine": "pr-review",
  "started_at": "2026-07-25T13:00:00Z",
  "duration_ms": 8412,
  "route": "local->premium",
  "escalated_reason": "reasoning_task",
  "tokens": {"input": 1204, "output": 812, "local_input": 640, "local_output": 88},
  "cost_usd": 0.0091,
  "tools_used": ["read_files", "run_shell"],
  "exit_status": 0,
  "output_excerpt": "First 500 chars of the routine's markdown output…",
  "output_url": "file:///var/lib/vinos/routines/state/pr-review/2026-07-25-1300.md"
}
```

`slack` and `discord` formats wrap the same payload into their
respective incoming-webhook shapes. Failures POST with `exit_status !=
0` and the last 500 chars of stderr under `error_excerpt`. Delivery is
best-effort — no retries, no queue; the routine's success does not
depend on the webhook returning 2xx.

## 6. Kubernetes deep dive — Helm chart schema

Full `values.yaml` skeleton (defaults shown):

```yaml
# ============================================================
# vinos-agents Helm chart — values.yaml (v2.1)
# ============================================================

image:
  repository: ghcr.io/vinpatel/vinos-cloud
  tag: "2.1"
  pullPolicy: IfNotPresent
  pullSecrets: []

# --- routine sources ---------------------------------------
# Exactly one of `routineSets.git` or `routineSets.configMap`
# should be set. If both are set, git wins with a warning.
routineSets:
  git:
    enabled: false
    url: ""                          # e.g. https://github.com/acme/monorepo
    ref: main
    path: .vinos/routines.yaml       # relative to repo root
    ssh:
      secretName: ""                 # optional — for private repos
      knownHostsSecretName: ""
    intervalSeconds: 300             # re-sync cadence
  configMap:
    enabled: true
    name: vinos-routines             # ConfigMap key: routines.yaml

# --- ollama sidecar ----------------------------------------
ollama:
  enabled: false                     # off by default — see §3.C rationale
  image: ollama/ollama:latest
  model: llama3.2:3b                 # preloaded on Deployment start
  service:
    port: 11434
  resources:
    requests: { cpu: 500m, memory: 4Gi }
    limits:   { cpu: 2000m, memory: 8Gi }
  gpu:
    enabled: false
    nvidiaCount: 1                   # requires nvidia device plugin
  persistence:
    enabled: true
    size: 20Gi
    storageClassName: ""

# --- anthropic (premium route) -----------------------------
anthropic:
  enabled: true                      # allow routines with route=anthropic|auto
  secretName: vinos-api-keys         # must contain key ANTHROPIC_API_KEY
  createSecret: false
  apiKey: ""                         # only used if createSecret=true (avoid)

# --- output sinks ------------------------------------------
webhook:
  url: ""                            # optional; empty disables
  format: generic-json               # generic-json | slack | discord
  secretName: ""                     # optional; key WEBHOOK_URL overrides `url`

# --- state -------------------------------------------------
storage:
  className: ""                      # cluster default
  accessMode: ReadWriteMany          # ReadWriteOnce also supported (see §3.C)
  size: 5Gi

# --- rbac + service account --------------------------------
serviceAccount:
  create: true
  name: ""                           # generated if empty
rbac:
  create: true                       # RoleBinding for Secret read only

# --- pod security ------------------------------------------
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile: { type: RuntimeDefault }
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities: { drop: ["ALL"] }

# --- network policy ----------------------------------------
networkPolicy:
  enabled: true
  extraEgressCIDRs: []               # e.g. corporate proxy, github enterprise

# --- global guardrails -------------------------------------
guardrails:
  maxDollarsPerDayGlobal: ""         # empty = disabled
  networkMode: allow-anthropic       # local-only | allow-anthropic | allow-all
  escalationCap: 3

# --- misc --------------------------------------------------
timezone: UTC
extraEnv: []                         # freeform env for the routine containers
tolerations: []
nodeSelector: {}
affinity: {}
```

### 6.1 What `helm template` emits for a single routine

Given a routine `pr-review` with `oncalendar: "*-*-* 09,13,17:00:00"`
and `route: auto`, the chart renders (abridged):

```yaml
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vinos-pr-review
  namespace: vinos-agents
  labels:
    app.kubernetes.io/name: vinos-agents
    app.kubernetes.io/component: routine
    vinos.computer/routine: pr-review
spec:
  schedule: "0 9,13,17 * * *"              # translated from oncalendar
  timeZone: America/New_York               # K8s 1.27+ CronJob field
  concurrencyPolicy: Forbid                # ledger writes serialize; no overlap
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 0                      # routines are idempotent-by-design
      template:
        spec:
          restartPolicy: Never
          serviceAccountName: vinos-agents
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 1000
          containers:
            - name: routine
              image: ghcr.io/vinpatel/vinos-cloud:2.1
              args: ["run", "pr-review"]
              env:
                - { name: OLLAMA_URL,   value: "http://vinos-ollama:11434" }
                - { name: TZ,           value: "America/New_York" }
                - { name: VINOS_WEBHOOK_URL, valueFrom: { secretKeyRef: { name: vinos-webhook, key: WEBHOOK_URL, optional: true } } }
              envFrom:
                - secretRef: { name: vinos-api-keys, optional: true }
              securityContext:
                readOnlyRootFilesystem: true
                allowPrivilegeEscalation: false
                capabilities: { drop: ["ALL"] }
              volumeMounts:
                - { name: state,    mountPath: /var/lib/vinos }
                - { name: routines, mountPath: /etc/vinos, readOnly: true }
                - { name: tmp,      mountPath: /tmp }
              resources:
                requests: { cpu: 100m, memory: 256Mi }
                limits:   { cpu: 1000m, memory: 1Gi }
          volumes:
            - name: state
              persistentVolumeClaim: { claimName: vinos-state }
            - name: routines
              configMap: { name: vinos-routines }
            - name: tmp
              emptyDir: {}
```

Every field on that manifest is a standard K8s primitive — no CRDs, no
operator, no admission webhooks. Any competent platform engineer can
`kubectl apply -f` the rendered output and it works.

## 7. Security posture

Enterprise IT reads this first. All claims map to a runtime primitive,
not a policy PDF.

**Local-first by default.** `ollama.enabled=false` means the chart ships
zero external egress unless the operator explicitly opts in. When
`anthropic.enabled=true` (default), only `api.anthropic.com:443` is
allowed by the NetworkPolicy; everything else is denied.

**Sandboxed shell tools.** Every `shell:<cmd>` invocation runs under
`bwrap` with `--unshare-net`, `--clearenv`, ro-bind of `/usr /etc /bin
/lib(64)`, tmpfs `/tmp`, and `--die-with-parent`. Same code path as
Desktop (see routine-spec §Tools). On Cloud the **userns bwrap path is
mandatory** — suid bwrap won't be present because the container runs
non-root. Requires the K8s node kernel to permit unprivileged user
namespaces (default on all mainstream distros since ~2022). If the node
disables them, the runtime fails closed: `run_shell` returns errors and
the routine still runs its text-only portions.

**No network egress in container unless explicitly allowed** — enforced
at two layers: bwrap `--unshare-net` per shell call, and K8s
NetworkPolicy on the pod.

**Read-only root filesystem.** `readOnlyRootFilesystem: true`. The only
writable mounts are `/var/lib/vinos` (state PVC) and `/tmp` (emptyDir).

**runAsNonRoot with explicit uid 1000.** No capabilities. Seccomp
RuntimeDefault. No privilege escalation.

**Secrets.** K8s Secret is the primary; external secret managers work
through their K8s-native integrations without any vinOS-side change:

- **SOPS** — decrypt to a K8s Secret via helm-secrets or sops-operator.
- **HashiCorp Vault** — vault-agent injector mounts a file at
  `/root/.vinos/secrets/anthropic-key` (the runtime already reads that
  path).
- **AWS Secrets Manager** — External Secrets Operator syncs to
  `vinos-api-keys`.
- **GCP Secret Manager** — same via ESO.
- **sealed-secrets** — bitnami-labs SealedSecret controller creates
  `vinos-api-keys`.

The chart references secrets by name only; it never materializes API
keys into `values.yaml` (the `createSecret` opt-in exists for demos
only, with a loud warning in the chart notes).

**Audit log.** Every run appends one JSON line to
`/var/lib/vinos/audit.log`:

```json
{"ts":"2026-07-25T13:00:00Z","routine":"pr-review","route":"local->premium",
 "escalated_reason":"reasoning_task","tools_used":["read_files","run_shell"],
 "input_tokens":1204,"output_tokens":812,"cost_usd":0.0091,
 "exit_status":0,"pod":"vinos-pr-review-28f01-abcde","namespace":"vinos-agents"}
```

The ledger (SQLite) is the queryable form; the JSONL audit log is the
append-only compliance form suitable for shipping to a SIEM via
Fluentbit / Vector / Filebeat.

**Compliance mapping.** Honest — items marked *aspirational* require a
sponsoring customer to fund formal attestation (see
`/for/enterprise/`).

| Control | Addressed by | Status |
|---|---|---|
| SOC 2 CC6.1 (logical access) | RBAC + Secret refs + non-root pod + no shell access to prod pods | primitive shipped |
| SOC 2 CC7.2 (system monitoring) | JSONL audit log + SQLite ledger | primitive shipped |
| SOC 2 CC8.1 (change management) | Routines are TOML in git; Helm chart versioned | primitive shipped |
| SOC 2 CC6.7 (data-in-transit) | HTTPS to Anthropic; in-cluster ollama is HTTP over pod network — TLS via service mesh if required | operator opts in |
| ISO 27001 A.8.24 (crypto) | ANTHROPIC_API_KEY at rest in K8s Secret (etcd-encrypted if operator enabled) | operator opts in |
| ISO 27001 A.8.32 (change control) | GitOps via `routineSets.git` re-sync | primitive shipped |
| GDPR Art. 32 (security of processing) | Local-first + explicit escalation + audit log | primitive shipped |
| GDPR Art. 30 (records of processing) | Ledger + audit log capture prompt hashes (not prompts) — full prompt logging is opt-in | primitive shipped |
| Formal SOC 2 Type II attestation | — | *aspirational* — sponsor-funded |
| Signed release binaries + SBOM | Cosign + syft in build pipeline | *aspirational* — v2.1.x |

## 8. Migration paths — Desktop → Cloud

For an engineer already running vinOS Desktop:

**Path A — GitOps (recommended).** Commit `.vinos/routines.yaml` to
your team repo. Point the Helm chart at it:

```
helm install vinos-agents vinos/agents \
  --set routineSets.git.enabled=true \
  --set routineSets.git.url=https://github.com/acme/monorepo \
  --set routineSets.git.path=.vinos/routines.yaml
```

Same file the laptop already loads via `vinos-routine load .`. No
translation, no drift.

**Path B — Export + apply.** For clusters without git-sync tolerance:

```
vinos-routine export --k8s > k8s/routines.yaml   # v2.1
kubectl apply -f k8s/routines.yaml
```

Emits raw CronJob manifests; skips the chart entirely. Useful when the
routine list rarely changes.

**Path C — Docker Compose (single-node).** For the "one $5 VPS"
founder:

```
vinos-routine export --docker > docker-compose.yml   # v2.1
docker compose up -d
```

Emits a compose file with one service per routine (using host cron
labels) plus a shared volume.

**State migration:**

| Data | Migrates? | How |
|---|---|---|
| `~/.vinos/routines/state/ledger.db` | optional | `scp` to `/var/lib/vinos/ledger.db`; schema is forward-compatible via runtime's `ALTER TABLE` on open |
| `~/.vinos/routines/state/<name>/memory.md` | optional | `rsync -a state/ user@host:/var/lib/vinos/routines/state/` |
| `~/.vinos/routines/state/<name>/*.md` outputs | usually skip | history stays on the laptop; cloud starts a fresh run history |
| Routine TOMLs written by hand under `~/.vinos/routines/` | no — convert to YAML | one-time: hand-edit into `.vinos/routines.yaml`; a `vinos-routine convert-toml-to-yaml` helper is a nice-to-have for v2.1.x |
| `ANTHROPIC_API_KEY` | manual | never `scp` — issue a fresh key, store in K8s Secret |

The runtime is byte-identical between Desktop and Cloud, so a routine
that works on the laptop is guaranteed to run in the cloud provided:
env vars are set, mounted paths are writable, and any `read:` globs
resolve to paths that exist in the container's filesystem (the common
gotcha — `read:~/inbox/*.eml` will resolve to `/root/inbox` inside the
pod, which is empty; migrate the data or change the glob).

## 9. MVP scope (v2.1.0) vs. deferred (v2.1.x)

**In v2.1.0** — the shipping trigger for the version tag:

- Docker image `ghcr.io/vinpatel/vinos-cloud:2.1` built + published,
  Alpine base, ~300 MB target
- Helm chart in `vinos.computer/helm` with the schema in §6
- Cloud-init deploy script for **Hetzner Cloud only**
  (`vinos.computer/cloud/deploy/hetzner.sh`)
- Webhook output sink (§5.1) — Slack, Discord, generic-JSON
- Multi-tenant via **K8s namespace** (cluster) or **systemd
  `DynamicUser=yes`** per timer unit (single-node nspawn)
- `vinos-routine export --k8s` and `--docker` (the two migration paths
  in §8)
- JSONL audit log at `/var/lib/vinos/audit.log`
- Read-only root FS + non-root + NetworkPolicy defaults on

**Deferred to v2.1.x** — post-launch, iterate as demand shows up:

- HTTP API (`POST /run/<name>`, `GET /routines`, `GET /ledger`) for
  on-demand triggering — unlocks Cloud Run + serverless targets
- WebSocket for live routine-output streaming (`/routines/<name>/stream`)
- DigitalOcean, Fly.io, GCP Cloud Run one-clicks
- Full GitOps sync agent (poll `routineSets.git.intervalSeconds` and
  reconcile CronJobs on change — v2.1.0 renders CronJobs once at helm
  install/upgrade time; changes to the git YAML require `helm upgrade`)
- Prometheus exporter for the ledger (`ledger_run_count_total`,
  `ledger_cost_usd_total`, `ledger_escalated_total{reason}`, …)
- `nspawn` first-class artifact (tar + `.nspawn` unit) on the release page
- SBOM + cosign signatures on the image (§7 compliance aspirational row)
- `vinos-routine convert-toml-to-yaml` helper

## 10. Non-goals

Explicit — what vinOS Cloud is **not**, so contributors don't waste time
proposing it:

- **Not a hosted SaaS by us.** No `vinos.cloud` control plane. Users
  self-host or use their own cloud accounts. The positioning against
  Zapier / n8n Cloud (§1) collapses if we run the workloads for you.
- **Not a Zapier / n8n replacement.** Those orchestrate SaaS APIs.
  vinOS Cloud orchestrates **your agents on your data** — the substrate
  is a Claude/Ollama LLM loop, not a workflow-node canvas.
- **Not a K8s operator.** Helm chart is primary. An operator adds a
  reconciler, CRDs, RBAC surface, and a code path that has to survive
  cluster upgrades — for marginal value over `helm upgrade` at this
  stage. If the community builds one, we'll link to it.
- **No web UI in v2.1.0.** Routines are code + CLI + webhook. A UI is
  v2.2+ and lives in the team-shared-routines direction. Building it
  before the multi-tenant story lands would trap us in single-user UX.
- **No proprietary scheduling language.** cron and systemd OnCalendar
  cover everything; the translator (`vinos_routine_cron.py`) already
  handles the union. We refuse Quartz-isms and Jenkins `H` tokens (see
  routine-spec cron coverage matrix).
- **No K8s-native "Routine" CRD.** Same rationale as no-operator — the
  Job → CronJob primitives are enough.

## 11. Shipping trigger — v2.1.0

Concrete criteria that MUST all be true before the version tag ships:

1. **Docker image built + published.** `ghcr.io/vinpatel/vinos-cloud:2.1`
   pullable by an anonymous `docker pull`. Signed (cosign) is
   aspirational — see §9 — but the image must exist and be < 400 MB
   uncompressed.
2. **Helm chart validated on two clusters.** Local `k3s` on a laptop
   (one-node smoke test) AND one production-ish target — either a
   Hetzner-hosted `k3s`, a DigitalOcean Kubernetes cluster, or a GKE
   Autopilot instance. Both must complete: install → CronJob visible →
   routine fires → ledger row written → webhook delivered.
3. **Documentation shipped.** `vinos.computer/for/platform/` copy
   updated to remove "coming v2.1" hedges and replace with the actual
   `helm install` + `curl … hetzner.sh` commands.
   `/docs/v2/vinos-cloud-spec.md` (this file) linked from ROADMAP.md.
4. **End-to-end demo.** One recorded flow:
   laptop develops `.vinos/routines.yaml` → commits to a public
   GitHub repo → `helm install --set routineSets.git.url=…` on a real
   cluster → CronJob fires on schedule → webhook posts to a live Slack
   channel → the same routine's output visible via `vinos-brief` on the
   laptop by rsync'ing the state PVC.
5. **Desktop routine → Cloud parity.** Take one of the shipped starter
   routines (`day-brief` or `github-review`) and run it verbatim in
   Cloud with only path/env substitutions. If it works on the laptop it
   works in the container.
6. **Hetzner one-click.** `curl … hetzner.sh` on a clean Ubuntu image
   ends with an active systemd timer firing a routine within 10 minutes.
   Script is idempotent (re-run = no-op if already installed).

Ship when 1-6 all true. If 2 slips, ship 2.1.0-rc.N until it converges.
Do **not** hold v2.1.0 for the deferred list in §9.

## 12. Related specs

- [vinos-routine-spec.md](vinos-routine-spec.md) — the runtime
  primitives Cloud runs verbatim: TOML schema, tool sandbox, auto-router,
  memory, ledger columns.
- [vinos-routines-yaml-spec.md](vinos-routines-yaml-spec.md) — the
  project-scoped YAML that GitOps mode consumes.
- [ROADMAP.md](ROADMAP.md) — v2.1 line-item, and the v2.2 (team-shared)
  and v2.3+ directions that inherit from Cloud.
- [ARCHITECTURE.md](ARCHITECTURE.md) — the substrate + overlay model
  that makes Desktop and Cloud siblings rather than forks.
