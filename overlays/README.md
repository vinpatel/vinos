# vinOS Overlays

Overlays are how vinOS ships opinionated variants without forking the
base repo. Per Rule 2:

- **Base owns install scripts 01–09.** Never edit these to bake in
  variant-specific behavior — those changes belong here.
- **Overlays own 10–99.** Anything you put in `overlays/<persona>/
  install/NN-thing.sh` runs after base's 09 by `install.sh --overlay
  overlays/<persona>`. Config files with the same basename shadow the
  base equivalents.
- **Overlays never mutate 01–09.** If a variant needs to change base
  behavior, propose a hook in base and consume it in the overlay.

## Current overlays

| Overlay | Persona | Bundles it preselects | Extra pkgs |
|---|---|---|---|
| `education/` | Teachers, students, community-lab machines. | office, browser, media | gcompris-qt, calibre, inkscape, kdenlive, scratch, kolibri, python |
| `health/`    | Clinicians, health researchers. AI intentionally omitted (patient-data privacy). | office, comms, productivity, browser | calibre, keepassxc, ffmpeg |

## How overlays interact with the first-boot notifier

`bin/vinos-install-once` reads every `/etc/vinos/first-boot.d/*.list`
at first boot and includes those bundle names in its notification.
Each overlay's `install/10-*.sh` writes its own `.list` — that's the
whole contract. New overlays don't need to touch the notifier.

## Building an ISO with an overlay

```bash
iso/build.sh --overlay overlays/education
```

Everything installer-side goes through `install.sh --overlay
overlays/education`. Both paths produce a bit-identical vinOS
underneath the overlay — the base is one source of truth.

## Adding a new overlay

1. `mkdir -p overlays/<name>/{install,config}`.
2. Write `install/10-<name>.sh` (persona packages + first-boot list).
3. Write `install/11-<name>-config.sh` if you need to shadow base
   configs (add e.g. `config/hypr/hyprland.conf` shadow entries).
4. Document persona + bundles in the table above.
