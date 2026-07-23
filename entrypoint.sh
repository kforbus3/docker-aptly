#!/bin/bash
set -e

GPG_EMAIL="${GPG_NAME_EMAIL:-repo@yourdomain.com}"

# Ensure required directories exist (the /data volume may start empty).
mkdir -p /root/.gnupg /data/gpg /data/packages /data/aptly/public
chmod 700 /root/.gnupg

# The container keyring (/root/.gnupg) is ephemeral, so the signing key must be
# (re)imported from the persistent /data volume on every start. On first boot a
# key is generated and saved to /data/gpg/private.key; to use your own key,
# place it there before the first start instead.
has_secret_key() {
    gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec:'
}

if ! has_secret_key && [ -f /data/gpg/private.key ]; then
    echo "Importing GPG signing key from /data/gpg/private.key..."
    gpg --batch --import /data/gpg/private.key
fi

if ! has_secret_key; then
    echo "No signing key found, generating a new GPG key..."

    # Create a GPG key batch file with configurable values.
    cat > /tmp/gpg-batch << EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: ${GPG_NAME_REAL:-Aptly Repository}
Name-Email: ${GPG_EMAIL}
Expire-Date: 0
%no-protection
%commit
EOF

    gpg --batch --generate-key /tmp/gpg-batch
    rm -f /tmp/gpg-batch

    # Persist the private key so it survives container recreation.
    gpg --export-secret-keys --armor "$GPG_EMAIL" > /data/gpg/private.key
    chmod 600 /data/gpg/private.key
    echo "GPG key generated; private key saved to /data/gpg/private.key"
fi

# Export (or refresh) the public half for clients, served at /gpg/public.key.
KEY_ID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/{print $5; exit}')
gpg --export --armor "$KEY_ID" > /data/gpg/public.key
chmod 644 /data/gpg/public.key
echo "GPG signing key ready (Key ID: $KEY_ID)."
echo "Public key exported to /data/gpg/public.key"

echo "Aptly + Nginx container is ready!"
echo "Repositories will be served at http://<host-ip>/"
echo "GPG public key available at http://<host-ip>/gpg/public.key"

# Start supervisord (manages nginx).
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
