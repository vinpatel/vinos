# prompts/all.sh — gum-driven UI. Collects everything downstream phases
# need. Writes to $ANSWERS so the disk/pacstrap/config phases can source
# the answers as plain shell vars.
#
# Ctrl-C at any prompt exits the phase non-zero — systemd restarts the
# service; on restart, preflight's marker is still present so we re-enter
# HERE, at the first unanswered prompt. That's the resume-from-crash story.

phase_start 20 prompts || return 0

# Load whatever preflight wrote so we can decide which prompts to ask.
answers_load
: "${HAS_ROUTE:=0}" "${HAS_WIFI:=0}" "${PROFILE:=generic}" "${CANDIDATE_DISKS:=}"

# ── UI helpers (thin wrappers over gum) ────────────────────────────
_banner() {
  clear
  gum style --border double --margin "1 2" --padding "1 3" \
    --border-foreground "#7BA7BC" --foreground "#F5D67B" \
    "vinOS installer" "" "$(cat /usr/share/vinos/VERSION 2>/dev/null || echo dev)"
}

_header() {
  gum style --foreground "#7BA7BC" --bold "▸ $*"
}

_confirm() {
  # $1 = prompt. Default No. Returns 0 iff user picks Yes.
  gum confirm --default=false "$1"
}

_choose() {
  # $1 = header, remaining = options. Prints picked option.
  local header="$1"; shift
  printf '%s\n' "$@" | gum choose --header "$header"
}

_input() {
  # $1 = placeholder, $2 = optional default value.
  local ph="$1" val="${2:-}"
  if [[ -n "$val" ]]; then
    gum input --placeholder "$ph" --value "$val"
  else
    gum input --placeholder "$ph"
  fi
}

_password() {
  gum input --password --placeholder "$1"
}

# ── wifi (optional) ────────────────────────────────────────────────
_wifi_prompt() {
  (( HAS_ROUTE == 1 )) && { log "wifi: skip (route already up)"; return 0; }
  (( HAS_WIFI == 1 )) || { log "wifi: no radio present; will require ethernet"; return 0; }

  _banner
  _header "Network"

  local dev
  dev="$(iwctl device list 2>/dev/null | awk 'NR>4 && $2 ~ /^wl/ {print $2; exit}')"
  [[ -n "$dev" ]] || { warn "no iwd-managed wireless device visible"; return 0; }

  rfkill unblock wifi 2>/dev/null || true
  iwctl device "$dev" set-property Powered on >/dev/null 2>&1 || true

  while :; do
    log "scanning wifi on $dev"
    iwctl station "$dev" scan >/dev/null 2>&1 || true
    sleep 2
    mapfile -t nets < <(
      iwctl station "$dev" get-networks 2>/dev/null \
        | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' \
        | awk 'NR>4 && NF>=2 { s=""; for (i=1;i<=NF-2;i++) s=(s?s" ":"")$i; sub(/^[>*]+[[:space:]]+/,"",s); if (length(s)) print s }' \
        | awk '!seen[$0]++'
    )
    nets+=("Enter SSID manually" "Rescan" "Skip Wi-Fi (I'll plug in Ethernet)")

    local ssid pass
    ssid="$(_choose "Pick a network on $dev" "${nets[@]}")" || die "wifi cancelled"
    case "$ssid" in
      Rescan) continue ;;
      "Skip Wi-Fi"*) return 0 ;;
      "Enter SSID manually")
        ssid="$(_input "SSID")" || continue
        [[ -n "$ssid" ]] || continue
        ;;
    esac
    pass="$(_password "Password for $ssid (empty for open)")" || continue

    log "connecting to '$ssid'"
    if [[ -n "$pass" ]]; then
      iwctl --passphrase "$pass" station "$dev" connect "$ssid" 2>&1 | tee -a "$LOG" || true
    else
      iwctl station "$dev" connect "$ssid" 2>&1 | tee -a "$LOG" || true
    fi

    for _i in $(seq 1 20); do
      if ip route show default | grep -q .; then
        log "wifi: got default route"
        HAS_ROUTE=1
        answers_write HAS_ROUTE "1" WIFI_SSID "$ssid"
        return 0
      fi
      sleep 1
    done
    warn "no default route within 20 s after connect attempt"
    _confirm "Try another network?" || return 0
  done
}
_wifi_prompt

# ── locale (keyboard + timezone) ───────────────────────────────────
_banner; _header "Keyboard layout"
KB_LAYOUT="$(_choose "Pick a keyboard layout" \
  "us — US English" \
  "gb — UK English" \
  "de — German" \
  "fr — French" \
  "es — Spanish" \
  "it — Italian" \
  "dvorak — Dvorak" \
  "colemak — Colemak" \
  "Other (type layout code)"
)" || die "locale cancelled"
if [[ "$KB_LAYOUT" == "Other"* ]]; then
  KB_LAYOUT="$(_input "layout code (e.g. 'us', 'de-nodeadkeys')")" || die "locale cancelled"
else
  KB_LAYOUT="${KB_LAYOUT%% *}"
fi
[[ -n "$KB_LAYOUT" ]] || KB_LAYOUT="us"
loadkeys "$KB_LAYOUT" >/dev/null 2>&1 || warn "loadkeys $KB_LAYOUT failed on live medium — still write to target"

_banner; _header "Timezone"
TIMEZONE=""
if [[ "$HAS_ROUTE" == "1" ]]; then
  if command -v tzupdate >/dev/null 2>&1; then
    TIMEZONE="$(timeout 6 tzupdate -p 2>/dev/null || true)"
  fi
  if [[ -z "$TIMEZONE" ]]; then
    TIMEZONE="$(timeout 6 curl -fsS https://ipapi.co/timezone 2>/dev/null || true)"
  fi
fi
if [[ -n "$TIMEZONE" ]]; then
  log "auto-detected timezone: $TIMEZONE"
  _confirm "Use $TIMEZONE?" || TIMEZONE=""
fi
if [[ -z "$TIMEZONE" ]]; then
  TIMEZONE="$(_input "Timezone (e.g. America/Los_Angeles)" "UTC")" || die "locale cancelled"
fi
if [[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
  warn "zoneinfo /usr/share/zoneinfo/$TIMEZONE missing — falling back to UTC"
  TIMEZONE="UTC"
fi

# ── disk pick ──────────────────────────────────────────────────────
_banner; _header "Disk"

_disk_options() {
  # Reformat CANDIDATE_DISKS into human-friendly rows with size + model.
  local d rows=()
  for d in $CANDIDATE_DISKS; do
    local size model
    size="$(lsblk -d -n -o SIZE "$d" 2>/dev/null | awk '{$1=$1;print}')"
    model="$(lsblk -d -n -o MODEL "$d" 2>/dev/null | awk '{$1=$1;print}')"
    rows+=("$d  ($size)  $model")
  done
  printf '%s\n' "${rows[@]}"
}
mapfile -t disk_rows < <(_disk_options)
DISK_PICK="$(_choose "Which disk should vinOS use? (ALL DATA WILL BE ERASED)" "${disk_rows[@]}")" \
  || die "disk cancelled"
DISK="${DISK_PICK%%  *}"

[[ -b "$DISK" ]] || die "picked $DISK is not a block device"
mounted=$(lsblk -n -o MOUNTPOINT "$DISK" | awk 'NF' | tr '\n' ' ')
for critical in / /boot /home /efi /boot/efi; do
  if grep -qE "(^| )${critical}( |$)" <<<" $mounted "; then
    die "$DISK is mounted at $critical — refusing (looks like the running system's disk)"
  fi
done

_banner
gum style --border double --border-foreground "#E9B872" --padding "1 3" --margin "1 4" \
  "$(printf 'About to WIPE %s' "$DISK")" \
  "$(lsblk "$DISK" -o NAME,SIZE,MODEL 2>/dev/null | sed 's/^/   /')"
_confirm "Continue? All data on $DISK will be permanently erased." \
  || die "wipe cancelled"

# ── account ────────────────────────────────────────────────────────
_banner; _header "Your account"
while :; do
  USERNAME="$(_input "Username (letters, digits, _-, no spaces)")" || die "user cancelled"
  [[ -n "$USERNAME" ]] || { warn "username cannot be empty"; continue; }
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || { warn "username must match ^[a-z_][a-z0-9_-]*$"; continue; }
  [[ ${#USERNAME} -le 32 ]] || { warn "username must be 32 chars or fewer"; continue; }
  break
done

while :; do
  p1="$(_password "Password for $USERNAME (min 6 chars)")" || die "password cancelled"
  p2="$(_password "Confirm password")" || die "password cancelled"
  [[ -n "$p1" && ${#p1} -ge 6 ]] || { warn "password too short"; continue; }
  [[ "$p1" == "$p2" ]] || { warn "passwords did not match"; continue; }
  PASSWORD="$p1"; unset p1 p2
  break
done

HOSTNAME_="$(_input "Hostname" "vinos")" || die "hostname cancelled"
[[ -n "$HOSTNAME_" ]] || HOSTNAME_="vinos"

# ── summary + confirm ──────────────────────────────────────────────
_banner; _header "Confirm"
gum style --margin "0 4" \
  "  disk:      $DISK" \
  "  user:      $USERNAME" \
  "  hostname:  $HOSTNAME_" \
  "  profile:   $PROFILE" \
  "  keyboard:  $KB_LAYOUT" \
  "  timezone:  $TIMEZONE" \
  "" \
  "About to partition the disk, pacstrap base Arch, install systemd-boot," \
  "and layer the vinOS overlay. Takes ~10-20 min."

_confirm "Start the install?" || die "install cancelled at final confirm"

# Persist. PASSWORD is scrubbed by finalize/all.sh after user creation.
answers_write \
  KB_LAYOUT  "$KB_LAYOUT"  \
  TIMEZONE   "$TIMEZONE"   \
  DISK       "$DISK"       \
  USERNAME   "$USERNAME"   \
  PASSWORD   "$PASSWORD"   \
  HOSTNAME_  "$HOSTNAME_"

phase_done 20 prompts
