---
name: Bug report
about: Something in Pinpoint crashed or didn't work
labels: bug
---

**What happened**

**What you expected**

**Steps to reproduce**
1.
2.

**Versions**
- Pinpoint: (menu bar icon → About, or the release you downloaded)
- macOS:

**Log excerpt**
Run this in Terminal right after the problem and paste the output (check it for anything private first):

```
log show --last 15m --info --predicate 'subsystem == "app.pinpoint.Pinpoint"'
```

**Crash report** (if Pinpoint quit unexpectedly)
Open Console, choose **Crash Reports**, select the newest `Pinpoint` entry and attach it or paste its first 60 lines.
