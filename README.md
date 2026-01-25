# Install Docker
sudo apt update
sudo apt install docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER  # Logout and login again after this





# Create the data directory structure
sudo mkdir -p /data/forterra/jammy /data/forterra/focal /data/published /data/aptly
sudo chown -R $(id -u):$(id -g) /data  # Adjust ownership as needed



# Clone or copy your aptly repository files to the target machine
# Make sure you have these files in your deployment directory:
# - Dockerfile
# - docker-compose.yml  
# - aptly.conf
# - nginx.conf
# - supervisord.conf
# - entrypoint.sh
# - update-snapshots.sh

# Build and start the service
docker-compose up -d

# Check if it's running
docker-compose ps
docker-compose logs -f  # To view logs




# Check if the service is running
curl http://localhost/health  # Should return "OK"

# Check published repositories (after adding .deb files)
curl http://localhost/






# Place your .deb files in the appropriate directories
sudo cp your-package.deb /data/forterra/jammy/

# Process and publish the new packages
docker-compose exec aptly-repo update-snapshots.sh

# Verify the packages are published
curl http://localhost/dists/jammy-artifacts/







# Add the repository
echo "deb [trusted=yes] http://YOUR_SERVER_IP/ jammy-artifacts main" | sudo tee /etc/apt/sources.list.d/custom-artifacts.list

# Update package lists
sudo apt update

# Install your custom packages
sudo apt install your-package-name






# Start the service
docker-compose up -d

# Stop the service
docker-compose down

# View logs
docker-compose logs -f

# Restart the service
docker-compose restart

# Rebuild the container (after making changes)
docker-compose build
docker-compose up -d

# Execute commands in the container
docker-compose exec aptly-repo bash
docker-compose exec aptly-repo update-snapshots.sh

# Backup the data
sudo tar -czf aptly-backup-$(date +%Y%m%d).tar.gz /data






# Check disk usage
du -sh /data/*

# Check container status
docker-compose ps

# View recent logs
docker-compose logs --tail=50

# Monitor system resources
docker stats aptly-repo-server






# Ubuntu/Debian (ufw)
sudo ufw allow 80/tcp

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload








#!/bin/bash
# backup-aptly.sh
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/aptly"

sudo mkdir -p $BACKUP_DIR
sudo tar -czf $BACKUP_DIR/aptly-backup-$DATE.tar.gz /data
echo "Backup completed: $BACKUP_DIR/aptly-backup-$DATE.tar.gz"






