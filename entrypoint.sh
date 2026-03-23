#!/bin/bash
set -e

# Create GPG directory if it doesn't exist
mkdir -p /root/.gnupg /data/gpg
chmod 700 /root/.gnupg

# Import existing GPG key if provided
if [ -f "/etc/aptly/private.key" ] && [ ! -f /data/gpg/aptly-key-imported ]; then
    echo "Importing existing GPG key..."
    gpg --import /etc/aptly/private.key
    
    # Get the key ID and export public key
    KEY_ID=$(gpg --list-secret-keys --keyid-format=long | grep sec | awk '{print $2}' | cut -d'/' -f2)
    if [ ! -z "$KEY_ID" ]; then
        gpg --export --armor $KEY_ID > /data/gpg/public.key
        echo "GPG key imported successfully!"
        echo "Key ID: $KEY_ID"
        echo "Public key exported to /data/gpg/public.key"
    fi
    
    touch /data/gpg/aptly-key-imported
elif [ ! -f /data/gpg/aptly-key-imported ]; then
    echo "No existing key found, generating new GPG key..."
    
    # Create GPG key batch file with configurable values
    cat > /tmp/gpg-batch << EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: ${GPG_NAME_REAL:-Aptly Repository}
Name-Email: ${GPG_NAME_EMAIL:-repo@yourdomain.com}
Expire-Date: 0
%no-protection
%commit
EOF
    
    # Generate the key
    gpg --batch --generate-key /tmp/gpg-batch
    
    # Export the public key for distribution to clients
    gpg --export --armor "repo@yourdomain.com" > /data/gpg/public.key
    
    touch /data/gpg/aptly-key-imported
    echo "GPG key generated successfully!"
    echo "Public key exported to /data/gpg/public.key"
fi

# Initialize aptly database if it doesn't exist
if [ ! -d "/data/aptly/db" ]; then
    echo "Initializing aptly database..."
    aptly db recover
fi

echo "Aptly+Nginx container is ready!"
echo "Repositories will be served at http://<host-ip>/"
echo "GPG public key available at http://<host-ip>/gpg/public.key"

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
