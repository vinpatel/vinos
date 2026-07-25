#!/usr/bin/env bash
# vinOS: create the generic brcmfmac firmware symlinks the driver
# actually asks for, pointing at the T2-model-specific files that
# apple-bcm-firmware ships. Fixes "Direct firmware load ... failed
# with error -2" on 2019+ T2 Macs where the linux-t2 DMI-detection
# patch doesn't fire.
#
# Runs as a systemd oneshot BEFORE iwd; cycles brcmfmac after so it
# re-probes with the new symlinks in place.
set -euo pipefail

FW=/lib/firmware/brcm
[[ -d "$FW" ]] || exit 0

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
case "$model" in
  # 13" 2018/2019 T2 MacBook Pros
  MacBookPro15,2|MacBookPro15,4|MacBookPro16,3) codename=fiji ;;
  # 15" 2018/2019 and 16" 2019/2020 T2 MacBook Pros
  MacBookPro15,1|MacBookPro15,3|MacBookPro16,1|MacBookPro16,4) codename=formosa ;;
  # 13" 2020 T2 MacBook Pro (4-port)
  MacBookPro16,2) codename=tahiti ;;
  *)
    # Fall back to formosa (most common); most T2 Airs/Minis also have this
    # firmware available. If wifi doesn't come up, dmesg will tell us the
    # right codename and we add a case.
    codename=formosa ;;
esac

logger -t vinos-t2-brcmfmac "model=$model → codename=$codename"

# Symlink the three chip firmware blobs + one NVRAM file. Idempotent.
for suffix in bin clm_blob txcap_blob; do
  src="$FW/brcmfmac4377b3-pcie.apple,${codename}.${suffix}"
  dst="$FW/brcmfmac4377b3-pcie.${suffix}"
  [[ -e "$src" ]] && ln -sf "$(basename "$src")" "$dst"
done
src="$FW/brcmfmac4377b3-pcie.apple,${codename}-SPPR-m.txt"
dst="$FW/brcmfmac4377b3-pcie.txt"
[[ -e "$src" ]] && ln -sf "$(basename "$src")" "$dst"

# Cycle brcmfmac so it re-probes with firmware now findable. If the module
# wasn't loaded (non-Broadcom hardware), rmmod fails silently — fine.
modprobe -r brcmfmac 2>/dev/null || true
modprobe brcmfmac 2>/dev/null || true
