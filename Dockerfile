FROM debian:bullseye-slim

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

# Create necessary directories
RUN mkdir -p /data/aptly /data/forterra /data/published

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

# Default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
