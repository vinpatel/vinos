#!/usr/bin/env bash
# iso/publish-release.sh — cut a GitHub Release and host the ISO on
# Backblaze B2. GitHub gets the release notes + sha256sums + a link
# to the B2 download. B2 gets the actual ISO (no 2 GiB cap; cheap
# storage + bandwidth-alliance-free egress if you front with
# Cloudflare later).
#
# Usage:
#   bash iso/publish-release.sh [TAG]
#     TAG defaults to v$(cat VERSION) — e.g. v1.0.0
#
# Requires the `b2` CLI (aur/b2-cli or pip install b2) authorized
# against your Backblaze account. Env vars this script reads:
#
#   VINOS_B2_BUCKET      bucket name       (default: vinos-releases)
#   VINOS_B2_URL_PREFIX  public URL prefix (default: https://f004.backblazeb2.com/file/vinos-releases)
#
# One-time B2 setup:
#   1. Create a Backblaze account (free tier: 10 GB storage + 1 GB/day egress).
#   2. Create a bucket named `vinos-releases` with type=Public.
#   3. Create an application key: bucket=vinos-releases, capabilities=
#      listFiles+readFiles+writeFiles+deleteFiles.
#   4. b2 account authorize <keyID> <appKey>
#   5. (Optional but recommended) put the bucket behind Cloudflare via
#      the Bandwidth Alliance to zero out egress costs.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ISO_DIR/.." && pwd)"
VERSION="$(<"$REPO/VERSION")"
TAG="${1:-v${VERSION}}"

B2_BUCKET="${VINOS_B2_BUCKET:-vinos-releases}"
B2_URL_PREFIX="${VINOS_B2_URL_PREFIX:-https://f004.backblazeb2.com/file/${B2_BUCKET}}"

die() { printf '\033[1;31m[release] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[release]\033[0m %s\n' "$*"; }

command -v b2 >/dev/null || die "b2 CLI not found. Install: pipx install b2 (or pacman -S b2-tools if available)"
command -v gh >/dev/null || die "gh CLI not found. Install: pacman -S github-cli"

# Confirm b2 is authorized.
if ! b2 account get >/dev/null 2>&1; then
  die "b2 not authorized. Run: b2 account authorize <keyID> <appKey>"
fi

ISO="$(find "$ISO_DIR/out" -maxdepth 1 -name 'vinos-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO in $ISO_DIR/out — run iso/build.sh first"

ISO_NAME="$(basename "$ISO")"
# Include the tag in the B2 key so old releases don't get clobbered.
B2_KEY="${TAG}/${ISO_NAME}"
ISO_URL="${B2_URL_PREFIX}/${B2_KEY}"
ISO_SIZE=$(stat -c %s "$ISO")

log "ISO   : $ISO_NAME ($(numfmt --to=iec-i --suffix=B "$ISO_SIZE"))"
log "B2    : b2://${B2_BUCKET}/${B2_KEY}"
log "URL   : $ISO_URL"

# Fresh sha256sums.
log "computing sha256"
( cd "$(dirname "$ISO")" && sha256sum "$ISO_NAME" > sha256sums.txt )
SHA=$(awk '{print $1}' "$ISO_DIR/out/sha256sums.txt")

# Upload to B2 (streaming — no local copy).
log "uploading to B2 (may take a while over your uplink)"
b2 file upload "$B2_BUCKET" "$ISO" "$B2_KEY"

# Release notes point at the B2 URL.
NOTES=$(cat <<EOF
## vinOS $VERSION

**Boot to Claude Code + a local LLM in 90 seconds.**

### Download

**ISO** ($(numfmt --to=iec-i --suffix=B "$ISO_SIZE")):

$ISO_URL

**SHA-256:**

\`\`\`
${SHA}  ${ISO_NAME}
\`\`\`

Or grab \`sha256sums.txt\` attached to this release.

### Install

**Path A — flash the ISO to USB:**

\`\`\`bash
curl -L -o ${ISO_NAME} ${ISO_URL}
sudo dd if=${ISO_NAME} of=/dev/sdX bs=4M status=progress conv=fsync && sync
\`\`\`

Boot the target machine off the USB. Live vinOS desktop appears in ~2 minutes. Then in a terminal:

\`\`\`bash
sudo vinos-install-disk
\`\`\`

Three prompts (disk, user, hostname). Auto-detects Apple T2 / NVIDIA / generic hardware. ~15 min end-to-end.

**Path B — layer onto existing Arch:**

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
\`\`\`

### Docs

Full install guide + keybindings + bundles: <https://vinpatel.github.io/vinos/>

### What's in this release

Every commit through $(git -C "$REPO" rev-parse --short HEAD). See [CHANGELOG](https://github.com/vinpatel/vinos/commits/main).
EOF
)

log "creating GitHub release $TAG (metadata only; ISO is on B2)"
if gh release view "$TAG" --repo vinpatel/vinos >/dev/null 2>&1; then
  log "release $TAG exists — updating notes + sha256sums"
  gh release edit "$TAG" --repo vinpatel/vinos --notes "$NOTES"
  gh release upload "$TAG" "$ISO_DIR/out/sha256sums.txt" --repo vinpatel/vinos --clobber
else
  gh release create "$TAG" "$ISO_DIR/out/sha256sums.txt" \
    --repo vinpatel/vinos \
    --title "vinOS $VERSION" \
    --notes "$NOTES"
fi

log "done."
log ""
log "  GitHub release : $(gh release view "$TAG" --repo vinpatel/vinos --json url --jq .url)"
log "  ISO download   : $ISO_URL"
