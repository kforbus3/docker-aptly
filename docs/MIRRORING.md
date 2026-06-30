# Mirroring Upstream Debian Repositories (Advanced)

The default workflow of this project hosts **your own** `.deb` artifacts (see the
main [README](../README.md)). If you additionally want to mirror upstream Debian
suites and serve them locally, the commands below are a reference. Run them inside
the container:

```bash
docker compose exec aptly-repo bash
```

> Note: full Debian mirrors are large (tens to hundreds of GB). Make sure
> `./data` has enough space before mirroring.

## Create mirrors

```bash
# amd64 main
aptly mirror create \
  -architectures=amd64 \
  dist-main \
  http://archive.debian.org/debian \
  stable \
  main contrib non-free

# arm64 (debian-ports) main
aptly mirror create \
  -architectures=arm64 \
  dist-ports-main \
  http://ftp.debian.org/debian-ports \
  unstable \
  main contrib non-free
```

## Update mirrors

```bash
aptly mirror update dist-main
aptly mirror update dist-ports-main
```

## Snapshot the mirrors

```bash
aptly snapshot create dist-main-$(date +%Y%m%d)       from mirror dist-main
aptly snapshot create dist-ports-main-$(date +%Y%m%d) from mirror dist-ports-main
```

## Publish the snapshots

```bash
aptly publish snapshot -distribution=stable   -component=main dist-main-$(date +%Y%m%d) .
aptly publish snapshot -distribution=unstable -component=main dist-ports-main-$(date +%Y%m%d) .
```

## Backports (optional)

```bash
aptly mirror create -architectures=amd64 dist-backports \
  http://archive.debian.org/debian stable-backports main contrib non-free
aptly mirror create -architectures=arm64 dist-backports-ports \
  http://ftp.debian.org/debian-ports unstable-backports main contrib non-free

aptly mirror update dist-backports
aptly mirror update dist-backports-ports

aptly snapshot create dist-backports-$(date +%Y%m%d)       from mirror dist-backports
aptly snapshot create dist-backports-ports-$(date +%Y%m%d) from mirror dist-backports-ports

aptly publish snapshot -distribution=stable-backports   -component=main dist-backports-$(date +%Y%m%d) .
aptly publish snapshot -distribution=unstable-backports -component=main dist-backports-ports-$(date +%Y%m%d) .
```

## Client sources.list entries

```
deb http://<your-repo>/ stable main
deb http://<your-repo>/ stable-backports main
```

Repeat the pattern for `stable-updates` and `stable-security` as needed.
