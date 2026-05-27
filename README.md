# CHIMERA Bootstrap (Public Install Repo)

This repo contains only bootstrap installer files.
No internal project sources are included.

Current release:

- `chimera.sh` bootstrap version `0.1.48`
- package: `chimera-pq-linux-x86_64-0.1.48.tar.gz`

## One-line install

```bash
curl -fsSL "https://raw.githubusercontent.com/neo-2022/chimera/main/chimera.sh?ts=$(date +%s)" | bash -s -- -install
```

## After install

```bash
chimera.sh -start
chimera.sh -status
chimera.sh -stop
chimera.sh -uninstall
```

On the first run CHIMERA opens mesh node selection and saves the chosen node
automatically.
