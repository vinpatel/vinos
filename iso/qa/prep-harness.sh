#!/usr/bin/env bash
#
# vinOS harness prep — one-shot Kimi K2 + Qwen + Hermes install & wire
#
# Run on the Omarchy dev SERVER (the box with the GPU), not the laptop.
# Exits 0 on GO, 0 with warnings on GO-WITH-CAUTION, 1 on NO-GO.
# All actions are user-space; no sudo. Idempotent — safe to re-run.
#
# Overridable env:
#   MODEL_DIR         GGUF download dir             (default: $HOME/models)
#   LOG_FILE          Prep log path                 (default: ~/vinos-prep-<date>.log)
#   KIMI_QUANT        Q4_K_M | Q5_K_M | Q8_0        (default: Q4_K_M)
#   MIN_VRAM_GB       Below this, force Qwen primary (default: 24)
#   QA_BASELINE_MIN   Passing threshold for QA-12   (default: 8 of 10)
#   SKIP_QA           Set to 1 to skip QA-12 loop   (default: unset)
#
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-$HOME/models}"
LOG_FILE="${LOG_FILE:-$HOME/vinos-prep-$(date +%F-%H%M).log}"
KIMI_QUANT="${KIMI_QUANT:-Q4_K_M}"
MIN_VRAM_GB="${MIN_VRAM_GB:-24}"
QA_BASELINE_MIN="${QA_BASELINE_MIN:-8}"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'; NC='\033[0m'
declare -i WARNS=0

log()     { echo -e "$(date +%H:%M:%S) $*" | tee -a "$LOG_FILE"; }
ok()      { log "${GRN}✓${NC} $*"; }
warn()    { log "${YEL}⚠${NC} $*"; WARNS+=1; }
die()     { log "${RED}✗${NC} $*"; exit 1; }
section() { echo | tee -a "$LOG_FILE"; log "═══ $* ═══"; }

: > "$LOG_FILE"
log "vinOS harness prep starting"
log "Log: $LOG_FILE"

# ── Step 1 · Hardware inventory ─────────────────────────────────────────────
section "1 · Hardware inventory"

if command -v nvidia-smi &>/dev/null; then
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | tee -a "$LOG_FILE"
  TOTAL_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits |
               awk '{s+=$1} END {printf "%d", s/1024}')
elif command -v rocm-smi &>/dev/null; then
  rocm-smi --showmeminfo vram 2>&1 | tee -a "$LOG_FILE" >/dev/null
  TOTAL_VRAM=$(rocm-smi --showmeminfo vram 2>/dev/null |
               awk '/Total.*B/{sum+=$NF} END {printf "%d", sum/1024/1024/1024}')
else
  warn "No GPU detected (no nvidia-smi or rocm-smi)"
  TOTAL_VRAM=0
fi
log "Total VRAM: ${TOTAL_VRAM} GB"

DISK_FREE_GB=$(df -BG "$HOME" | awk 'NR==2 {gsub(/G/,""); print $4}')
log "Free disk in \$HOME: ${DISK_FREE_GB} GB"
[[ $DISK_FREE_GB -lt 150 ]] && warn "<150 GB free — Kimi Q4_K_M is ~110 GB"

RAM_GB=$(free -g | awk 'NR==2 {print $2}')
log "System RAM: ${RAM_GB} GB"

# Primary model decision
if   [[ $TOTAL_VRAM -ge 120 ]]; then PRIMARY="kimi-k2";              ok "VRAM sufficient for full Kimi K2"
elif [[ $TOTAL_VRAM -ge 40  ]]; then PRIMARY="kimi-k2";              ok "VRAM sufficient for Kimi K2 $KIMI_QUANT"
elif [[ $TOTAL_VRAM -ge $MIN_VRAM_GB ]]; then PRIMARY="qwen2.5-coder:32b"; warn "VRAM too low for Kimi — using Qwen primary"
else                                 PRIMARY="qwen2.5-coder:32b";    warn "VRAM below threshold — Qwen may be slow"
fi
log "PRIMARY MODEL: $PRIMARY"

# ── Step 2 · Ollama service ─────────────────────────────────────────────────
section "2 · Ollama service"

command -v ollama &>/dev/null || die "ollama not installed. Install: curl -fsSL https://ollama.com/install.sh | sh"
ok "ollama: $(ollama --version 2>&1 | head -1)"

if   systemctl --user is-active ollama &>/dev/null; then ok "ollama running (user service)"
elif systemctl        is-active ollama &>/dev/null; then ok "ollama running (system service)"
elif curl -sf http://localhost:11434/api/tags &>/dev/null; then ok "ollama reachable on :11434"
else die "ollama not running. Try: systemctl --user start ollama"
fi

# ── Step 3 · Model pulls ────────────────────────────────────────────────────
section "3 · Model pulls (this can take an hour on first run)"

model_present() { ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$1"; }

if [[ "$PRIMARY" == "kimi-k2" ]]; then
  if model_present "kimi-k2"; then
    ok "kimi-k2 already present"
  elif ollama pull kimi-k2 2>&1 | tee -a "$LOG_FILE" | tail -1 | grep -qi "success"; then
    ok "kimi-k2 pulled from registry"
  else
    warn "kimi-k2 not in Ollama registry — trying GGUF path"
    mkdir -p "$MODEL_DIR/kimi"

    if ! command -v huggingface-cli &>/dev/null; then
      log "Installing huggingface_hub..."
      pip install -q --user -U huggingface_hub 2>&1 | tee -a "$LOG_FILE" || die "pip install huggingface_hub failed"
      export PATH="$HOME/.local/bin:$PATH"
    fi

    KIMI_FILE="Kimi-K2-Instruct-${KIMI_QUANT}.gguf"
    if [[ -f "$MODEL_DIR/kimi/$KIMI_FILE" ]]; then
      ok "$KIMI_FILE already downloaded"
    else
      log "Downloading $KIMI_FILE from HuggingFace..."
      huggingface-cli download bartowski/Kimi-K2-Instruct-GGUF \
        "$KIMI_FILE" \
        --local-dir "$MODEL_DIR/kimi" \
        --local-dir-use-symlinks False 2>&1 | tee -a "$LOG_FILE" | tail -3
    fi

    cat > /tmp/Modelfile-kimi <<EOF
FROM $MODEL_DIR/kimi/$KIMI_FILE
PARAMETER num_ctx 32768
PARAMETER temperature 0.2
PARAMETER top_p 0.9
SYSTEM You are Kimi Code, a fast local coding assistant for the vinOS project. Emit code, edit configs, write tests, draft docs. Escalate to Claude when a task requires cross-file architecture or security review.
EOF
    ollama create kimi-k2 -f /tmp/Modelfile-kimi 2>&1 | tee -a "$LOG_FILE" | tail -3
    ok "kimi-k2 registered from GGUF"
  fi
fi

if model_present "qwen2.5-coder:32b"; then
  ok "qwen2.5-coder:32b already present"
else
  ollama pull qwen2.5-coder:32b 2>&1 | tee -a "$LOG_FILE" | tail -3
  ok "qwen2.5-coder:32b pulled"
fi

# ── Step 4 · Smoke tests ────────────────────────────────────────────────────
section "4 · Smoke test each model"

smoke() {
  local model="$1"
  local start elapsed out
  start=$(date +%s)
  out=$(timeout 60 ollama run "$model" "Write a bash oneliner that prints today's date in ISO-8601 format." 2>&1 || echo "TIMEOUT")
  elapsed=$(( $(date +%s) - start ))
  log "$model — ${elapsed}s — $(echo "$out" | tr '\n' ' ' | head -c 160)"
  echo "$out" | grep -qE "date|%[YFT]|iso" || warn "$model smoke output looks off"
}

smoke "$PRIMARY"
smoke "qwen2.5-coder:32b"

# ── Step 5 · Hermes wire ────────────────────────────────────────────────────
section "5 · Hermes wire"

if command -v hermes &>/dev/null; then
  ok "hermes: $(hermes --version 2>&1 | head -1)"
  hermes config set endpoint.ollama http://localhost:11434  2>&1 | tee -a "$LOG_FILE" >/dev/null
  hermes config set model.default    "$PRIMARY"             2>&1 | tee -a "$LOG_FILE" >/dev/null
  hermes config set model.checker    "qwen2.5-coder:32b"    2>&1 | tee -a "$LOG_FILE" >/dev/null
  hermes config set model.researcher "$PRIMARY"             2>&1 | tee -a "$LOG_FILE" >/dev/null
  ok "Hermes wired: default=$PRIMARY  checker=qwen2.5-coder:32b"

  log "Hermes E2E test..."
  he_out=$(timeout 60 hermes run "print hello world in python" 2>&1 || echo "TIMEOUT")
  echo "$he_out" | grep -qi "print" && ok "Hermes E2E passed" || warn "Hermes E2E ambiguous — inspect log"
else
  warn "hermes not on PATH — dev flow will call Ollama directly; install Hermes later"
fi

# ── Step 6 · QA-12 baseline (10-prompt accuracy) ────────────────────────────
if [[ -n "${SKIP_QA:-}" ]]; then
  section "6 · QA-12 baseline SKIPPED (SKIP_QA set)"
  PASS_COUNT=$QA_BASELINE_MIN
else
  section "6 · QA-12 baseline (10-prompt accuracy check)"

  # prompts kept in the same order as KEYWORDS below
  PROMPTS=(
    "Write a bash function that checks if a package is installed via pacman."
    "Write a Hyprland keybinding that opens Foot terminal on Super+Return."
    "Write a systemd .service unit for a Python daemon at /usr/bin/vinos-agent that restarts on failure."
    "Write a TOML routine spec with schedule=hourly and route=auto — include tools list."
    "Write a mkinitcpio hook that copies brcmfmac firmware into the initramfs."
    "Write a sudoers rule allowing user 'vinos' to run pacman -Syu without password."
    "Write a bash test that verifies /etc/vinos-release exists and matches semver v1.0.19."
    "Write an awk one-liner that filters archiso packages.x86_64 to exclude lines starting with '#' or blank."
    "Write a Helm CronJob template for a vinos-routine that runs every 15 minutes."
    "Write a bwrap invocation that isolates /home but shares /tmp read-write."
  )
  KEYWORDS=(
    "pacman -Q"
    "bind.*(SUPER|Super)"
    "\\[Service\\]"
    "schedule.*hourly"
    "brcmfmac"
    "NOPASSWD"
    "1\\.0\\.19|semver|semantic"
    "awk|grep"
    "CronJob|schedule:"
    "bwrap.*(--bind|--ro-bind|--tmpfs)"
  )

  PASS_COUNT=0
  for i in "${!PROMPTS[@]}"; do
    q=$((i+1))
    log "Q${q}: ${PROMPTS[$i]}"
    ans=$(timeout 45 ollama run "$PRIMARY" "${PROMPTS[$i]}" 2>&1 || echo "TIMEOUT")
    if echo "$ans" | grep -qE "${KEYWORDS[$i]}"; then
      ok "  Q${q} pass"
      PASS_COUNT=$((PASS_COUNT+1))
    else
      log "  Q${q} miss (looked for /${KEYWORDS[$i]}/)"
    fi
  done
  log "QA-12 baseline: ${PASS_COUNT}/10"
fi

# ── Step 7 · Backup ─────────────────────────────────────────────────────────
section "7 · Backup working config"

BACKUP="$HOME/kimi-ollama-backup-$(date +%F-%H%M).tar.gz"
tar czf "$BACKUP" \
  -C "$HOME" \
  .ollama/models/manifests \
  .hermes 2>/dev/null || true
[[ -f "$BACKUP" ]] && ok "Backup: $BACKUP ($(du -h "$BACKUP" | cut -f1))" || warn "Backup skipped — no manifests/config yet"

# ── Verdict ─────────────────────────────────────────────────────────────────
section "Summary"
log "Primary model : $PRIMARY"
log "QA-12 baseline: ${PASS_COUNT}/10  (threshold: ${QA_BASELINE_MIN}/10)"
log "Warnings      : $WARNS"
log "Log           : $LOG_FILE"
log "Backup        : ${BACKUP:-none}"
echo

if [[ $PASS_COUNT -lt $QA_BASELINE_MIN ]]; then
  echo -e "${RED}══════════════════════════════════════${NC}"
  echo -e "${RED}  NO-GO — QA-12 baseline below threshold${NC}"
  echo -e "${RED}  Do NOT start Phase 0 until this passes${NC}"
  echo -e "${RED}══════════════════════════════════════${NC}"
  exit 1
elif [[ $WARNS -gt 0 ]]; then
  echo -e "${YEL}══════════════════════════════════════${NC}"
  echo -e "${YEL}  GO-WITH-CAUTION — $WARNS warning(s)   ${NC}"
  echo -e "${YEL}  Review the log before Phase 0         ${NC}"
  echo -e "${YEL}══════════════════════════════════════${NC}"
  exit 0
else
  echo -e "${GRN}══════════════════════════════════════${NC}"
  echo -e "${GRN}  GO — Phase 0 cleared to execute       ${NC}"
  echo -e "${GRN}══════════════════════════════════════${NC}"
  exit 0
fi
