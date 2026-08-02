# Docker + Kubernetes-Optimized Runtime (Phase B2b)

**Phase:** B
**Version target:** 2.1.0
**Status:** in-progress
**Owner:** claude
**Memory entry:** [k8s-optimized](memory/project_k8s_optimized.md)
**Harness check IDs:** #56 → #63

## 1. Problem statement

Agent operators run a lot of containers — local LLM inference servers (ollama, vllm), development databases (postgres, redis), sidecar services (traefik, minio), full-stack agents that use docker-compose to orchestrate their own tool chain. Kubernetes-based agents are increasingly common (Argo Workflows for pipelines, KServe for model serving). vinOS today ships `docker` in a bundle but the base kernel and system tuning aren't optimized for it. On a fresh install you can't `docker run`, you can't `kubectl apply`, and there's no single-node k8s cluster in one command.

## 2. User story

As a **founder building an agent stack**, I want `docker` and `kubectl` and a working local k8s cluster available with minimal setup, so that I can run my inference server, my agent pipeline, and my prod-parity dev environment all as containers without spending a day tuning sysctl and installing 20 packages.

## 3. Behavior spec

### Inputs

- Fresh vinOS 2.1.0 install
- `sudo vinos-install-k8s` command available in `$PATH`

### Behavior

**Base install (no extra command needed):**
- `docker` daemon installed, `docker.service` enabled
- User in `docker` group (added by installer)
- `docker-compose` (the plugin, not the deprecated separate binary)
- `containerd` running with proper config
- `kubectl` binary in `$PATH`
- Container-required kernel modules in initramfs
- Sysctl tuning for containers applied

**Optional (via `sudo vinos-install-k8s`):**
- Initialize a single-node cluster via `kubeadm init`
- Cilium CNI installed and running
- `helm` installed
- `k9s` installed (TUI dashboard)
- Node labeled and taints removed (so pods schedule on the control plane)
- Kubeconfig placed at `~/.kube/config` for the user
- Test pod deployed to verify: `kubectl run nginx --image=nginx`

**Sysctl `/etc/sysctl.d/99-vinos-k8s.conf`:**
```
# Bridge netfilter — required by kube-proxy
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Kubelet expects these
vm.overcommit_memory = 1
vm.panic_on_oom = 0

# File watchers (npm, webpack, prometheus scrapers all hit these)
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 8192

# Large memory maps (jvm apps, elasticsearch)
vm.max_map_count = 262144

# Ephemeral port range (dev apps opening many outbound connections)
net.ipv4.ip_local_port_range = 32768 65535

# TCP keepalive (long-running gRPC, model streaming)
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
```

**cgroups v2 required:**
- Kernel cmdline: `systemd.unified_cgroup_hierarchy=1` (default in modern systemd anyway)
- Docker configured to use `systemd` cgroup driver:
  ```json
  /etc/docker/daemon.json:
  {
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {"max-size": "100m", "max-file": "3"},
    "storage-driver": "overlay2"
  }
  ```
- Containerd config aligned:
  ```
  /etc/containerd/config.toml:
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
  ```

### Non-behavior

- Do NOT auto-start k8s cluster on boot — user opts in with `vinos-install-k8s`
- Do NOT install `microk8s` or `k3s` — kubeadm is the standard, and users can install k3s themselves if they want minimal footprint
- Do NOT install prometheus + grafana in base — that's a `vinos-install-observability` bundle later

### Error paths

- If `docker.service` fails to start on target: `journalctl -u docker` shows why, common cause is missing overlay module (check #54 guards this)
- If `kubeadm init` fails: `sudo vinos-install-k8s` prints the kubeadm error and links to `docs/troubleshooting/k8s.md`

## 4. Harness checks

```bash
# #56: docker installed on target
if [[ -x "$ROOT/usr/bin/docker" ]] || grep -q 'docker' "$ROOT/etc/pacman.d/../var/lib/pacman/local/docker-"* 2>/dev/null; then
  ok "docker installed"
else
  fail "docker missing from base install" \
       "k8s-optimized"
fi

# #57: containerd installed + config uses systemd cgroup driver
if [[ -f "$ROOT/etc/containerd/config.toml" ]] && \
   grep -q 'SystemdCgroup = true' "$ROOT/etc/containerd/config.toml"; then
  ok "containerd uses systemd cgroup driver"
else
  fail "containerd config missing or not using systemd cgroups" \
       "k8s-optimized"
fi

# #58: docker daemon.json uses systemd cgroups + overlay2
if [[ -f "$ROOT/etc/docker/daemon.json" ]] && \
   grep -q 'native.cgroupdriver=systemd' "$ROOT/etc/docker/daemon.json" && \
   grep -q '"storage-driver": "overlay2"' "$ROOT/etc/docker/daemon.json"; then
  ok "docker daemon.json optimized (systemd cgroups, overlay2)"
else
  fail "docker daemon.json missing or misconfigured" \
       "k8s-optimized"
fi

# #59: kubectl in path
if [[ -x "$ROOT/usr/bin/kubectl" ]]; then
  ok "kubectl in \$PATH"
else
  fail "kubectl not installed" \
       "k8s-optimized"
fi

# #60: k8s sysctl config shipped
if [[ -f "$ROOT/etc/sysctl.d/99-vinos-k8s.conf" ]] && \
   grep -q 'net.bridge.bridge-nf-call-iptables = 1' "$ROOT/etc/sysctl.d/99-vinos-k8s.conf" && \
   grep -q 'fs.inotify.max_user_watches = 1048576' "$ROOT/etc/sysctl.d/99-vinos-k8s.conf"; then
  ok "container/k8s sysctl tuning shipped"
else
  fail "99-vinos-k8s.conf missing or incomplete" \
       "k8s-optimized"
fi

# #61: docker service enabled by default
if [[ -L "$ROOT/etc/systemd/system/multi-user.target.wants/docker.service" ]]; then
  ok "docker.service enabled by default"
else
  fail "docker.service not enabled — user has to enable manually" \
       "k8s-optimized"
fi

# #62: vinos-install-k8s bundle exists and is executable
if [[ -x "$ROOT/usr/share/vinos/bin/vinos-install-k8s" ]] || \
   [[ -x "$ROOT/usr/local/bin/vinos-install-k8s" ]]; then
  ok "vinos-install-k8s bundle available"
else
  fail "vinos-install-k8s missing — no one-command k8s init" \
       "k8s-optimized"
fi

# #63: container tools in bundle (podman, crun, helm, k9s)
_missing=""
for tool in podman crun helm k9s; do
  if ! find "$ROOT/usr/bin" -name "$tool" -o -name "${tool}*" 2>/dev/null | head -1 | grep -q .; then
    _missing="$_missing $tool"
  fi
done
if [[ -z "$_missing" ]]; then
  ok "container ecosystem tools present (podman, crun, helm, k9s)"
else
  fail "missing container tools:$_missing" \
       "k8s-optimized"
fi
```

## 5. Memory entry

New: `~/.claude/projects/-data-projects-vinos/memory/project_k8s_optimized.md`

## Implementation

### Files created

- `iso/profile/airootfs/etc/sysctl.d/99-vinos-k8s.conf`
- `iso/profile/airootfs/etc/docker/daemon.json`
- `iso/profile/airootfs/etc/containerd/config.toml`
- `bin/vinos-install-k8s` — one-command k8s init script
- `bin/vinos-k8s-status` — check cluster + node health

### Files modified

- `iso/profile/packages.x86_64` — add `docker docker-compose docker-buildx containerd runc crun podman kubectl kubeadm kubelet helm`
- `iso/aur.list` — add `k9s cilium-cli` (may need AUR)
- `install/04-services.sh` — enable `docker.service`, `containerd.service`
- `bin/vinos-install-disk` — add current user to `docker` group during install

### Package additions

Base packages (in every install):
- `docker`, `docker-compose`, `docker-buildx`
- `containerd`, `runc`, `crun`, `podman`
- `kubectl`

Bundle-only (`sudo vinos-install-k8s`):
- `kubeadm`, `kubelet`, `helm`, `k9s`, `cilium-cli`

## Testing

1. Build 2.1.0 with container packages
2. Harness runs #56-#63, all pass
3. Fresh install
4. `docker run hello-world` works without setup
5. `docker-compose --version` reports v2+
6. `sudo vinos-install-k8s` completes in < 5 min
7. `kubectl get nodes` shows Ready
8. `kubectl run nginx --image=nginx` deploys and reaches Running
9. `k9s` opens with cluster visible

## Rollback

Container packages are additive — if we hit an issue, remove from `packages.x86_64` and ship next release without them. User can install manually.
