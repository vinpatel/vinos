---
title: "Troubleshooting"
description: "Common issues by symptom. If your problem isn't listed, vinos-doctor is a good first move."
weight: 60
---

Every symptom below has been seen on real hardware — either during
alpha testing, in issue reports, or during the maintainer's own
daily use.

- **[Wi-Fi on T2 MacBooks](/docs/troubleshooting/wifi-t2/)** — the 8-item
  recipe that gets Broadcom firmware working reliably.
- **[Docker not running](/docs/troubleshooting/docker-not-running/)** —
  lazydocker "Cannot connect" fixes.
- **[Theme picker empty](/docs/troubleshooting/theme-picker-empty/)** —
  historic issue, fixed since v2.0.3; here for older installs.

Before you file an issue, please attach:

```
$ vinos-doctor > /tmp/doctor.log
$ vinos-hw-report > /tmp/hw.md
```

Those two together let us reproduce and answer without a back-and-forth.
