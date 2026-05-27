# CHIMERA Bootstrap (Public Install Repo)

This repo contains only bootstrap installer files.
No internal project sources are included.

Current release:

- `chimera.sh` bootstrap version `0.1.21`
- package: `chimera-pq-linux-x86_64-0.1.21.tar.gz`

## One-line install

```bash
curl -fsSL "https://raw.githubusercontent.com/neo-2022/chimera/main/chimera.sh?ts=$(date +%s)" | bash -s -- -install
```

Bootstrap prefers system `python3` for download/verify/extract flows and no longer requires a manual `curl` install on the target system.

If `curl` is not available, this Python-only bootstrap also works on a clean OS that already has `python3`:

```bash
python3 - <<'PY'
import subprocess, time, urllib.request

url = "https://raw.githubusercontent.com/neo-2022/chimera/main/chimera.sh?ts=%d" % int(time.time())
script = urllib.request.urlopen(url, timeout=30).read()
subprocess.run(["bash", "-s", "--", "-install"], input=script, check=True)
PY
```

## After install

```bash
chimera.sh -start
chimera.sh -status
chimera.sh -stop
chimera.sh -uninstall
```
