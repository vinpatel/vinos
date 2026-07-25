---
title: "Theme picker empty"
description: "Historic issue where vinos-theme --pick showed no options on first launch. Fixed in v2.0.3 with cache pre-warm; here for older installs."
weight: 30
---

## The symptom

On an old install (v2.0.2 and earlier):

```
$ vinos-theme --pick
```

Walker opens with an empty picker list — no themes shown. `vinos-theme`
by itself lists themes fine, but the walker overlay is empty.

**Fixed since v2.0.3.** If you're on the latest ISO, this doesn't apply.
Left in the docs because a lot of external write-ups reference the bug.

## The cause

Walker caches its providers' available items on first launch. The
theme picker uses a custom Walker provider that queried
`/usr/share/vinos/themes/` — but on first boot the cache hadn't been
warmed, and walker treated the empty cache as an empty result set.

## The fix (< v2.0.3)

Warm the walker cache manually:

```
$ walker --gapplication-service &
$ sleep 2
$ vinos-theme --pick
```

Or invalidate the cache and let the next `--pick` rebuild it:

```
$ rm -rf ~/.cache/walker/
$ vinos-theme --pick
```

## The fix (v2.0.3+)

`vinos-first-run` now pre-warms the walker cache on install. No user
action needed.

If you're on v2.0.3+ and *still* see an empty picker, it's a different
bug — please file with the output of:

```
$ vinos-theme
$ ls /usr/share/vinos/themes/
$ ls ~/.cache/walker/
```
