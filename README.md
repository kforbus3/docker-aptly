# Docker Aptly Repository Server

A self-contained, Docker-based **Debian/Ubuntu package repository** powered by
[aptly](https://www.aptly.info/) and served by nginx. Drop your `.deb` files in a
folder, run one command, and you have a GPG-signed `apt` repository your machines
can install from.

![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)
![Docker](https://img.shields.io/badge/docker-compose-blue.svg)

---

## Why

Setting up a signed apt repository by hand (aptly config, GPG keys, publishing,
a web server) is fiddly. This project bundles all of it into a single container
with sensible defaults so a homelab or IT ops team can stand one up in minutes.

## Features

- **One-command deploy** with Docker Compose.
- **Automatic GPG key generation** on first start (or bring your own key).
- **Signed publishing** — clients verify package signatures, no `[trusted=yes]`.
- **Snapshot-based workflow** via `update-snapshots.sh`.
- **Multiple distributions** — one per folder under `data/packages/`.
- **GPG public key served over HTTP** for easy client onboarding.
- **Health endpoint** (`/health`) for monitoring and orchestration.
- **Persistent state** in a project-local `./data` directory — easy to back up.

## How it works

```
        ┌──────────────────────────── container ────────────────────────────┐
.deb ─▶ │ data/packages/<dist>/  ──aptly──▶ snapshot ──publish (GPG sign)──▶ │
files   │                                              data/aptly/public/    │ ──HTTP──▶ apt clients
        │                                   nginx serves  /  and  /gpg/      │
        └────────────────────────────────────────────────────────────────────┘
```

All state lives under `./data` on the host (bind-mounted to `/data` in the
container):

| Path | Contents |
|------|----------|
| `data/packages/<dist>/` | Your input `.deb` files, one folder per distribution |
| `data/aptly/` | aptly database + the published repo (`data/aptly/public`, served at `/`) |
| `data/gpg/` | GPG keyring artifacts and the exported `public.key` (served at `/gpg/`) |

## Prerequisites

- Docker and Docker Compose (the installer can set these up on Debian/Ubuntu/RHEL)
- On Linux: a user that can talk to the Docker daemon (the `docker` group)

## Quick start

```bash
# 1. Build and start
docker compose up -d            # or: ./install.sh

# 2. Add packages (one folder per distribution)
mkdir -p data/packages/dist1
cp my-package_1.0_amd64.deb data/packages/dist1/

# 3. Publish them (creates a signed snapshot and publishes it)
docker compose exec aptly-repo update-snapshots.sh

# 4. Verify
curl -fsS http://localhost/health                # -> OK
curl -fsS http://localhost/gpg/public.key | head # -> PGP PUBLIC KEY BLOCK
```

The repository is now served at `http://<host-ip>/` and the distribution is
named `<dist>-artifacts` (e.g. `dist1` → `dist1-artifacts`).

### Automated installer

`./install.sh` wraps the above: it checks for Docker/Compose (installing them on
supported Linux distros), creates the `data/` folders, optionally opens port 80
in the firewall, and brings the stack up. It detects `docker compose` (v2) and
falls back to `docker-compose` (v1).

## Adding a client

On a Debian/Ubuntu machine (full details in [docs/CLIENT_SETUP.md](docs/CLIENT_SETUP.md)):

```bash
curl -fsSL http://YOUR_SERVER_IP/gpg/public.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/aptly-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/aptly-archive-keyring.gpg] http://YOUR_SERVER_IP/ dist1-artifacts main" \
  | sudo tee /etc/apt/sources.list.d/custom-artifacts.list

sudo apt update && sudo apt install my-package
```

## Configuration

Set these in `docker-compose.yml` under `environment:`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GPG_NAME_REAL` | `Aptly Repository` | Real name on the generated GPG key |
| `GPG_NAME_EMAIL` | `repo@yourdomain.com` | Email/identity on the generated GPG key |
| `TZ` | `UTC` | Container timezone |

aptly behavior (architectures, dependency following, etc.) lives in
[`aptly.conf`](aptly.conf).

### Bring your own GPG key

To sign with an existing key instead of an auto-generated one, export it and
place it at `data/gpg/private.key` **before the first start**:

```bash
gpg --export-secret-keys --armor YOUR_KEY_ID > data/gpg/private.key
docker compose up -d
```

The container imports it and exports the matching public key to
`data/gpg/public.key`. The included [`generate_gpg_key`](generate_gpg_key) script
can also create a key pair for you.

> **Never commit `data/gpg/private.key` (or any private key) to git.** The
> provided `.gitignore` already excludes `data/` and key material.

## Operations

```bash
docker compose up -d            # start
docker compose down             # stop
docker compose restart          # restart
docker compose logs -f          # follow logs
docker compose ps               # status
docker compose exec aptly-repo bash   # shell inside the container
```

### Publishing updates

After adding or replacing `.deb` files, re-run:

```bash
docker compose exec aptly-repo update-snapshots.sh
```

Each run imports new packages, creates a timestamped snapshot, and (re)publishes
the `<dist>-artifacts` distribution with a fresh GPG signature.

### Backups

All state is under `./data`:

```bash
tar -czf aptly-backup-$(date +%Y%m%d).tar.gz data/
```

Store backups securely — `data/gpg/` contains your signing key.

## Security notes

- Packages are **GPG-signed**; clients verify signatures before install.
- The auto-generated key has **no passphrase** (`%no-protection`) so the
  container can sign unattended. For higher assurance, generate a key elsewhere
  and mount it, and restrict access to `data/gpg/`.
- The container serves **HTTP** on port 80. For anything beyond a trusted
  network, front it with a TLS-terminating reverse proxy (and consider an auth
  layer for private repositories).
- Rotate signing keys periodically and back up `data/` before doing so.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Packages 404 over HTTP | Did you run `update-snapshots.sh` after adding `.deb`s? |
| `apt update` can't verify | Re-import the key from `/gpg/public.key` on the client |
| Wrong architecture not seen | Client arch must match the package arch (`amd64`/`arm64`) |
| Container won't start | `docker compose logs` |
| Health check | `curl http://localhost/health` should return `OK` |

## Advanced: mirroring upstream Debian

To additionally mirror upstream Debian suites, see
[docs/MIRRORING.md](docs/MIRRORING.md).

## Project structure

```
docker-aptly/
├── Dockerfile              # aptly + nginx + supervisor image
├── docker-compose.yml      # service definition (bind-mounts ./data)
├── install.sh              # automated setup helper
├── entrypoint.sh           # GPG key import/generate + startup
├── update-snapshots.sh     # import .debs, snapshot, sign, publish
├── generate_gpg_key        # optional standalone key generator
├── aptly.conf              # aptly configuration
├── nginx.conf              # serves the published repo and GPG key
├── supervisord.conf        # runs nginx in the container
├── docs/
│   ├── CLIENT_SETUP.md     # configuring apt clients
│   └── MIRRORING.md        # mirroring upstream Debian (advanced)
├── LICENSE                 # Apache License 2.0
├── NOTICE                  # attribution
└── CONTRIBUTING.md
```

## License

Licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) and
[`NOTICE`](NOTICE).
