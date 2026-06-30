#!/bin/bash
set -e

GPG_EMAIL="${GPG_NAME_EMAIL:-repo@yourdomain.com}"

# Ensure required directories exist (the /data volume may start empty).
mkdir -p /root/.gnupg /data/gpg /data/packages /data/aptly/public
chmod 700 /root/.gnupg

# Import an existing GPG key if one was provided, otherwise generate a new one.
# Drop your own key at /data/gpg/private.key on the host to use it.
if [ -f "/data/gpg/private.key" ] && [ ! -f /data/gpg/aptly-key-imported ]; then
    echo "Importing existing GPG key from /data/gpg/private.key..."
    gpg --import /data/gpg/private.key

    # Determine the imported key ID and export its public half for clients.
    KEY_ID=$(gpg --list-secret-keys --keyid-format=long | awk '/^sec/{print $2}' | cut -d'/' -f2 | head -1)
    if [ -n "$KEY_ID" ]; then
        gpg --export --armor "$KEY_ID" > /data/gpg/public.key
        echo "GPG key imported successfully (Key ID: $KEY_ID)."
        echo "Public key exported to /data/gpg/public.key"
    fi

    touch /data/gpg/aptly-key-imported
elif [ ! -f /data/gpg/aptly-key-imported ]; then
    echo "No existing key found, generating a new GPG key..."

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

    # Export the public key for distribution to clients.
    gpg --export --armor "$GPG_EMAIL" > /data/gpg/public.key

    touch /data/gpg/aptly-key-imported
    echo "GPG key generated successfully!"
    echo "Public key exported to /data/gpg/public.key"
fi

echo "Aptly + Nginx container is ready!"
echo "Repositories will be served at http://<host-ip>/"
echo "GPG public key available at http://<host-ip>/gpg/public.key"

# Start supervisord (manages nginx).
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
