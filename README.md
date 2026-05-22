# CHIMERA Bootstrap (Public Install Repo)

This repo contains only bootstrap installer files.
No internal project sources are included.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/<ORG>/chimera/main/chimera.sh | bash -s -- -install
```

## After install

```bash
chimera.sh -start
chimera.sh -status
```

## Required archive URL

Set product archive URL before install if not embedded:

```bash
export CHIMERA_PQ_ARCHIVE_URL="https://<your-host>/chimera-pq-latest.tar.gz"
```
