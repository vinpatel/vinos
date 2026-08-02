# LUKS Encryption in Installer (Phase B2)

**Phase:** B
**Version target:** 2.1.0
**Status:** in-progress
**Owner:** claude
**Memory entry:** [luks-installer-roadmap](memory/project_luks_installer_roadmap.md)
**Harness check IDs:** #41 → #48

## 1. Problem statement

vinOS positions itself as "the most secure OS in the agentic era." Today the installer produces an **unencrypted** target disk. If the laptop is stolen or lost, everything an agent operator cared about — Anthropic API keys in `~/.config`, local model prompt histories, ollama cached weights, browser sessions, git credentials, ssh keys, `.aws/`, `.kube/`, GPG keys — is readable by anyone who plugs the drive into another machine. Systemd-boot also emits a "random seed is world-accessible" warning during install that alarms users, even though it's cosmetic on unencrypted /boot. Both problems close when we ship LUKS full-disk encryption for root.

## 2. User story

As a **founder running vinOS on my daily-driver laptop**, I want the disk encrypted by default (with the option to skip), so that a lost or stolen machine can't leak my API keys, prompt histories, or in-flight routine state — and so that the "secure OS" positioning matches the shipped installer.

## 3. Behavior spec

### Inputs

- Disk chosen in Phase 2/9 of the installer
- New prompt in Phase 3/9 (before user creation): "Encrypt disk? (recommended) [Y/n]"
- On yes: separate disk-unlock passphrase (min 8 chars; distinct from user password)
- Optional flag `--luks` / `--no-luks` for non-interactive installs
- Optional flag `--luks-tpm2` for auto-unlock via TPM2 (skips passphrase at boot)

### Behavior

**Interactive path — disk encryption enabled:**

1. After Phase 3 (username / password / hostname), installer prompts:
   ```
   Encrypt the disk with LUKS? (recommended) [Y/n]:
   ```
2. On `Y` (default): prompt for LUKS passphrase twice, min 8 chars.
3. On `n`: skip LUKS setup, proceed to Phase 4 partitioning unencrypted (current behavior).

**Partitioning (Phase 4) with LUKS:**

1. GPT + EFI (512M FAT32) + LUKS-formatted root partition (rest).
2. `cryptsetup luksFormat --type luks2 --hash sha512 --pbkdf argon2id /dev/nvme0n1p2` with the passphrase.
3. `cryptsetup open /dev/nvme0n1p2 vinos_root` — opens as `/dev/mapper/vinos_root`.
4. `mkfs.ext4 -L vinos-root /dev/mapper/vinos_root`.
5. Mount `/dev/mapper/vinos_root` on `/mnt`, EFI on `/mnt/boot`.

**Clone (Phase 5) — unchanged.** Runs against `/mnt`, doesn't care about LUKS underneath.

**Configure (Phase 6) with LUKS:**

1. `/etc/crypttab` on target:
   ```
   vinos_root  UUID=<luks-container-uuid>  none  luks,discard
   ```
2. `mkinitcpio.conf` HOOKS on target must include `encrypt` before `filesystems`:
   ```
   HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
   ```
3. Regenerate initramfs with new HOOKS.
4. Bootloader entry cmdline:
   ```
   options root=/dev/mapper/vinos_root rw quiet splash cfg80211.ieee80211_regdom=US cryptdevice=UUID=<luks-uuid>:vinos_root
   ```

**TPM2 optional (`--luks-tpm2`) — Phase 6.5:**

1. If the T2 has a TPM2 module accessible: `systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2`.
2. Add `sd-encrypt` hook alongside `encrypt` in mkinitcpio.conf.
3. Target boots without passphrase prompt — sd-encrypt pulls key from TPM2.
4. Fallback: passphrase still works if TPM2 fails or is reset.

**On first boot:**

1. Systemd-boot loads.
2. Kernel boots initramfs.
3. `encrypt` hook prompts: `Enter passphrase for /dev/nvme0n1p2 (vinos_root):`
4. User types passphrase (or TPM2 auto-unlocks if enabled).
5. Root mounts, systemd continues, greetd shows tuigreet.

### Non-behavior

- Does NOT encrypt `/boot`. That's a FAT32 ESP by UEFI spec. The random-seed warning during install remains — install summary now says: `Note: /boot random-seed warning is cosmetic. Only your ESP is unencrypted; all other data is behind LUKS.`
- Does NOT support swap encryption in v2.1.0 (add in 2.2.0 if there's a swap partition).
- Does NOT support re-encrypting an existing install. Encryption is fresh-install only.
- Does NOT support keyfiles on removable media (may add later).

### Error paths

- Passphrase < 8 chars: reprompt with `passphrase too short (min 8 chars)`.
- Passphrases don't match: reprompt.
- `cryptsetup luksFormat` fails: exit 7 with `LUKS format failed — see /tmp/vinos-install.log`.
- `cryptsetup open` fails: exit 8.
- TPM2 requested but not present: warn `TPM2 not available; will require passphrase at boot`, proceed without TPM2 enrollment.

## 4. Harness checks

Add to `iso/qa/verify-shipped-iso.sh`:

```bash
# #41: installer offers a LUKS prompt
if grep -q 'Encrypt.*disk.*LUKS' "$INSTALLER"; then
  ok "installer offers LUKS encryption option"
else
  fail "installer no longer prompts for LUKS encryption" \
       "luks-installer-roadmap"
fi

# #42: cryptsetup + argon2 required
if grep -q 'cryptsetup luksFormat.*luks2' "$INSTALLER" && \
   grep -q 'argon2id' "$INSTALLER"; then
  ok "installer uses LUKS2 + argon2id (modern KDF)"
else
  fail "installer LUKS uses weak params — expected luks2 + argon2id" \
       "luks-installer-roadmap"
fi

# #43: encrypt hook added to target mkinitcpio when LUKS enabled
if grep -q 'HOOKS=.*encrypt.*filesystems' "$INSTALLER"; then
  ok "mkinitcpio encrypt hook wired before filesystems"
else
  fail "encrypt hook missing or in wrong order — target won't unlock LUKS at boot" \
       "luks-installer-roadmap"
fi

# #44: crypttab written on target
if grep -q '/etc/crypttab' "$INSTALLER" && \
   grep -q 'vinos_root.*UUID' "$INSTALLER"; then
  ok "crypttab written with UUID reference"
else
  fail "crypttab missing or misconfigured on target" \
       "luks-installer-roadmap"
fi

# #45: cryptdevice cmdline in bootloader entry
if grep -q 'cryptdevice=UUID.*:vinos_root' "$INSTALLER"; then
  ok "systemd-boot entry has cryptdevice kernel cmdline"
else
  fail "systemd-boot entry missing cryptdevice — LUKS won't unlock" \
       "luks-installer-roadmap"
fi

# #46: minimum passphrase length enforced
if grep -q 'min 8 chars\|-ge 8' "$INSTALLER"; then
  ok "LUKS passphrase min 8 chars enforced"
else
  fail "LUKS passphrase length not validated" \
       "luks-installer-roadmap"
fi

# #47: TPM2 flag exists (--luks-tpm2)
if grep -q '\-\-luks-tpm2' "$INSTALLER"; then
  ok "TPM2 auto-unlock flag exists"
else
  fail "--luks-tpm2 flag missing" \
       "luks-installer-roadmap"
fi

# #48: cryptsetup + systemd-cryptenroll shipped in live ISO
if [[ -x "$ROOT/usr/bin/cryptsetup" ]] && \
   [[ -x "$ROOT/usr/bin/systemd-cryptenroll" ]]; then
  ok "cryptsetup + systemd-cryptenroll available on live for LUKS install"
else
  fail "cryptsetup or systemd-cryptenroll missing from live ISO" \
       "luks-installer-roadmap"
fi
```

## 5. Memory entry

Exists: [luks-installer-roadmap](../../memory/project_luks_installer_roadmap.md)

Update after ship: change status from `planned` → `shipped`, note TPM2 behavior on user's T2 (T2 has an Apple T2 chip that acts as a secure enclave, not a standards TPM2 — probably falls back to passphrase).

## Implementation

### Files modified

- `bin/vinos-install-disk` — add:
  - `--luks` / `--no-luks` / `--luks-tpm2` flags
  - Phase 3.5 prompt for LUKS + passphrase
  - Phase 4 partitioning branches on LUKS
  - Phase 6 mkinitcpio + crypttab + bootloader adjustments

### Package additions

- `cryptsetup` (usually already installed via `base`)
- `systemd-cryptenroll` (part of systemd; verify shipping)

### Files created

- `docs/spec/b-luks-installer.md` (this file)

### Migration notes

- Cannot migrate an existing unencrypted install. Doc mentions manual workflow: back up `~`, reinstall with `--luks`, restore `~`.

## Testing

1. `bash iso/build.sh` — build 2.1.0-rc-luks ISO
2. `bash iso/qa/verify-shipped-iso.sh iso/out/vinos-2.1.0-rc-luks-x86_64.iso` — checks #41-#48 must pass
3. Flash + install with LUKS enabled, passphrase `test-pass-2026`
4. Reboot into installed target
5. Verify passphrase prompt appears before greetd
6. Enter passphrase — boot completes to login
7. `sudo blkid /dev/nvme0n1p2` — must show `TYPE="crypto_LUKS"`
8. `sudo cryptsetup luksDump /dev/nvme0n1p2` — must show LUKS2, argon2id
9. Reboot with wrong passphrase — must reprompt, no boot
10. If `--luks-tpm2` used: reboot with no passphrase — must auto-unlock

## Rollback plan

If LUKS ships broken and can't be hotfixed in a day:

1. Revert `bin/vinos-install-disk` to 2.0.18 partition code
2. Ship 2.1.1 without LUKS support
3. Users who already installed 2.1.0 with LUKS keep working — no action needed on their end
4. Investigate + fix in a 2.1.2 that reintroduces LUKS
