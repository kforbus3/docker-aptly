FROM debian:trixie-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    aptly \
    gnupg \
    nginx-light \
    supervisor \
    wget \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories.
# /data/aptly/public is where aptly publishes and what nginx serves; creating it
# up front lets nginx start cleanly before the first publish.
RUN mkdir -p /data/aptly/public /data/packages /data/gpg

# Copy configuration files
COPY aptly.conf /etc/aptly.conf
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY update-snapshots.sh /usr/local/bin/update-snapshots.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/update-snapshots.sh

# Expose port 80
EXPOSE 80

# Set working directory
WORKDIR /data

# Environment variables for GPG key generation
ENV GPG_NAME_REAL="Aptly Repository"
ENV GPG_NAME_EMAIL="repo@yourdomain.com"

# entrypoint.sh prepares the GPG key, then execs supervisord itself.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
