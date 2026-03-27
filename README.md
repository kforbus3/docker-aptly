# Docker Aptly Repository Server

A Docker-based Debian repository server using Aptly for package management and Nginx for serving packages.

## Features

- Host your own Debian package repository
- Automated GPG key generation and management
- Snapshot-based publishing workflow
- Multiple distribution support
- HTTP health endpoint for monitoring
- Secure package signing with GPG
- Automated installation script

## Prerequisites

The automated installation script will handle Docker installation if needed. Otherwise, you need:

- Docker and Docker Compose installed
- User account with sudo privileges (Linux only)

## Automated Installation

The easiest way to set up the repository server is to use the provided installation script:

```bash
# Make the script executable
chmod +x install.sh

# Run the installation (will install Docker if needed)
./install.sh
```

The script will:
1. Check if Docker is installed (install if missing)
2. Add your user to the docker group (Linux only, requires re-login if added)
3. Create required directories with proper permissions
4. Configure firewall rules to allow HTTP traffic
5. Build and start the Docker containers
6. Verify the installation

**Note for macOS users**: The script will detect macOS and provide instructions to install Docker Desktop manually.

## Manual Setup (Alternative)

If you prefer to set up manually or are on an unsupported platform:

### 1. Install Docker

Install Docker and Docker Compose according to your platform:
- [Docker Desktop for Mac/Windows](https://www.docker.com/products/docker-desktop)
- [Docker Engine for Linux](https://docs.docker.com/engine/install/)

### 2. Create Data Directories

Create the required directory structure:

```bash
sudo mkdir -p /data/packages/dist1 /data/packages/dist2 /data/published /data/aptly /data/gpg
sudo chown -R $(id -u):$(id -g) /data  # Adjust ownership as needed
```

### 3. Configure Firewall (Linux only)

Allow HTTP traffic on port 80:

**Using ufw:**
```bash
sudo ufw allow 80/tcp
```

**Using firewalld:**
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

### 4. Deploy the Service

Build and start the service:

```bash
docker-compose build
docker-compose up -d
```

### 5. Verify Installation

Check if the service is running:

```bash
curl http://localhost/health  # Should return "OK"
```

View the published repositories:
```bash
curl http://localhost/
```

## Configuration

### Environment Variables

You can customize the GPG key generation by setting these environment variables in the docker-compose.yml:

- `GPG_NAME_REAL`: Real name for GPG key (default: "Aptly Repository")
- `GPG_NAME_EMAIL`: Email for GPG key (default: "repo@yourdomain.com")

Example docker-compose.yml modification:
```yaml
environment:
  - TZ=UTC
  - GPG_NAME_REAL=My Organization
  - GPG_NAME_EMAIL=packages@myorg.com
```

### Using Your Own GPG Key

To use your own GPG key instead of the auto-generated one:

1. Export your private key:
```bash
gpg --export-secret-keys --armor YOUR_KEY_ID > private.key
```

2. Place it in `/data/gpg/private.key` on the host

3. Restart the service:
```bash
docker-compose down
docker-compose up -d
```

## Custom GPG Key Generation Script

If you want more control over GPG key generation, you can use the provided `generate_gpg_key` script:

```bash
# Edit the script to customize key parameters
nano generate_gpg_key

# Run the script to generate a new key
docker-compose exec aptly-repo /usr/local/bin/generate_gpg_key
```

## Usage

### Adding Packages

Place your `.deb` files in the appropriate directories:

```bash
sudo cp your-package.deb /data/packages/dist1/
```

Process and publish the new packages:

```bash
docker-compose exec aptly-repo update-snapshots.sh
```

Verify the packages are published:
```bash
curl http://localhost/dists/dist1-artifacts/
```

### Client Configuration

On client machines, add the repository:

1. Download and add the GPG key:
```bash
curl -fsSL http://YOUR_SERVER_IP/gpg/public.key | sudo gpg --dearmor -o /usr/share/keyrings/aptly-archive-keyring.gpg
```

2. Add repository entry:
```bash
echo "deb [signed-by=/usr/share/keyrings/aptly-archive-keyring.gpg] http://YOUR_SERVER_IP/ dist1-artifacts main" | sudo tee /etc/apt/sources.list.d/custom-artifacts.list
```

3. Update and install packages:
```bash
sudo apt update
sudo apt install your-package-name
```

## Management Commands

Start the service:
```bash
docker-compose up -d
```

Stop the service:
```bash
docker-compose down
```

View logs:
```bash
docker-compose logs -f
```

Restart the service:
```bash
docker-compose restart
```

Rebuild the container (after making changes):
```bash
docker-compose build
docker-compose up -d
```

Execute commands in the container:
```bash
docker-compose exec aptly-repo bash
docker-compose exec aptly-repo update-snapshots.sh
```

## Maintenance

### Backups

Create backups of your data:

```bash
sudo tar -czf aptly-backup-$(date +%Y%m%d).tar.gz /data
```

Or use the provided backup script:
```bash
#!/bin/bash
# backup-aptly.sh
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/aptly"

sudo mkdir -p $BACKUP_DIR
sudo tar -czf $BACKUP_DIR/aptly-backup-$DATE.tar.gz /data
echo "Backup completed: $BACKUP_DIR/aptly-backup-$DATE.tar.gz"
```

### Monitoring

Check disk usage:
```bash
du -sh /data/*
```

Check container status:
```bash
docker-compose ps
```

View recent logs:
```bash
docker-compose logs --tail=50
```

Monitor system resources:
```bash
docker stats aptly-repo-server
```

## Troubleshooting

### Common Issues

1. **Packages not showing up**: Ensure you've run `update-snapshots.sh` after adding new packages.

2. **GPG verification errors**: Check that the client has properly imported the public key.

3. **Permission issues**: Ensure `/data` directory has proper ownership (`chown -R $(id -u):$(id -g) /data`).

4. **Container won't start**: Check logs with `docker-compose logs`.

### Health Checks

Verify service is running:
```bash
curl http://localhost/health  # Should return "OK"
```

List publications:
```bash
docker-compose exec aptly-repo aptly publish list
```

After running the installation script, you'll need to:

1. If the script added your user to the docker group, logout and login again
2. Place your .deb files in the appropriate directories under `/data/forterra/`
3. Run the update script to process packages: `docker-compose exec aptly-repo update-snapshots.sh`

## Project Structure

```
/data/
├── aptly/          # Aptly database and metadata
├── packages/       # Package storage organized by distribution
│   ├── dist1/      # Distribution 1 packages
│   └── dist2/      # Distribution 2 packages
├── published/      # Published repository files served by Nginx
└── gpg/            # GPG keys
```

## Security Considerations

1. **Network Security**: 
   - Only expose necessary ports (port 80 by default)
   - Use HTTPS in production environments with a reverse proxy
   - Configure firewall rules appropriately

2. **Package Security**: 
   - All packages are signed with GPG keys
   - Clients verify signatures before installation
   - Regularly rotate GPG keys

3. **Access Control**: 
   - Consider placing behind authentication proxy for private repositories
   - Restrict access to the /data directory on the host
   - Use strong SSH key authentication for server access

4. **Container Security**:
   - Run containers with minimal privileges
   - Regularly update base images
   - Monitor container logs for suspicious activity