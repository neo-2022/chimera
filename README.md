# CHIMERA Bootstrap (Legacy Public Install Repo)

This repo is retained for bootstrap history.
The current public install/update entry point is the `chimera-pq` release
bootstrap.

Current install source:

- `chimera.sh` bootstrap from `chimera-pq` GitHub Release/Latest
- package: `chimera-pq-release.tar.gz`

## One-line install

```bash
bash -o pipefail -c 'curl --disable -fsSL --retry 3 --connect-timeout 10 --max-time 60 https://github.com/neo-2022/chimera-pq/releases/latest/download/chimera.sh | bash -s -- -install'
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
