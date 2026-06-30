# Client Setup

How to consume packages from the repository on a Debian/Ubuntu client.

Replace `YOUR_SERVER_IP` with your repository server's address, and
`dist1-artifacts` with the distribution you published (the directory name under
`./data/packages/` plus the `-artifacts` suffix).

```bash
# 1. Download and install the repository signing key
curl -fsSL http://YOUR_SERVER_IP/gpg/public.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/aptly-archive-keyring.gpg

# 2. Add the repository (signed-by ties it to the key above)
echo "deb [signed-by=/usr/share/keyrings/aptly-archive-keyring.gpg] http://YOUR_SERVER_IP/ dist1-artifacts main" \
  | sudo tee /etc/apt/sources.list.d/custom-artifacts.list

# 3. Update and install
sudo apt update
sudo apt install YOUR_PACKAGE
```

Because the repository is GPG-signed, you do **not** need `[trusted=yes]`; apt
verifies signatures against the key you imported in step 1.
