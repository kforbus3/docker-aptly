# Contributing to Docker Aptly

Thanks for your interest in improving this project!

## Reporting issues

- Search existing issues first.
- Include reproduction steps, expected vs. actual behavior, and your environment
  (OS, Docker/Compose version).
- **Never** paste real GPG private keys, signing material, or other secrets into
  an issue or pull request.

## Development & testing

The whole stack runs in one container. To test a change locally:

```bash
docker compose build
docker compose up -d

# Add a package and publish it
mkdir -p data/packages/dist1
cp some-package_1.0_amd64.deb data/packages/dist1/
docker compose exec aptly-repo update-snapshots.sh

# Verify it is served and signed
curl -fsS http://localhost/health
curl -fsS http://localhost/gpg/public.key | gpg --import
curl -fsS http://localhost/dists/dist1-artifacts/InRelease | gpg --verify
```

Tear down with `docker compose down`. Remove `./data` to start from a clean slate.

## Pull requests

1. Keep changes focused and well-described (what changed and why).
2. Match the existing shell style; keep scripts `set -e` safe.
3. Update `README.md` / `docs/` when behavior or configuration changes.
4. Verify the build and the publish/serve workflow still pass before submitting.

## License

By contributing, you agree that your contributions will be licensed under the
[Apache License 2.0](LICENSE).
