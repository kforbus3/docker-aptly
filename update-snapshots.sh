#!/bin/bash
set -e

echo "Starting artifact snapshot update process..."

# Get GPG key ID for signing
GPG_KEY_ID=""
if [ -f "/etc/aptly/private.key" ]; then
    # Use imported key
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=short | grep sec | head -1 | awk '{print $2}' | cut -d'/' -f2)
elif [ -f /data/gpg/aptly-key-imported ]; then
    # Use generated key
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=short | grep sec | head -1 | awk '{print $2}' | cut -d'/' -f2)
fi

# Function to import deb files into local repository
import_deb_files() {
    local distro=$1
    local deb_dir="/data/packages/$distro"
    
    if [ ! -d "$deb_dir" ]; then
        echo "Directory $deb_dir does not exist, skipping..."
        return
    fi
    
    # Create local repository if it doesn't exist
    if ! aptly repo show "local-$distro" >/dev/null 2>&1; then
        echo "Creating local repository for $distro with neutral distribution..."
        aptly repo create -distribution=local -component=main "local-$distro"
    fi
    
    # Import new .deb files
    echo "Checking for new .deb files in $deb_dir..."
    find "$deb_dir" -name "*.deb" -type f | while read deb_file; do
        if ! aptly repo show "local-$distro" | grep -q "$(basename "$deb_file")"; then
            echo "Importing $(basename "$deb_file") into local-$distro..."
            aptly repo add "local-$distro" "$deb_file"
        else
            echo "$(basename "$deb_file") already imported, skipping..."
        fi
    done
}

# Function to create and publish snapshot for artifacts with signing
create_and_publish_artifacts() {
    local distro=$1
    local artifact_distro="${distro}-artifacts"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local snapshot_name="${distro}-artifacts-snapshot-${timestamp}"
    
    echo "=== Processing $distro artifacts ==="
    
    # Check if local repo exists and has .deb files
    if [ ! -n "$(find "/data/packages/$distro" -name "*.deb" -type f 2>/dev/null)" ]; then
        echo "No .deb files found in /data/packages/$distro, skipping..."
        return
    fi
    
    echo "Found .deb files, proceeding with import..."
    import_deb_files "$distro"
    
    # Create snapshot from local repository
    echo "Creating snapshot $snapshot_name..."
    if ! aptly snapshot show "$snapshot_name" >/dev/null 2>&1; then
        aptly snapshot create "$snapshot_name" from repo "local-$distro"
        echo "Snapshot $snapshot_name created successfully!"
    else
        echo "Snapshot $snapshot_name already exists, using existing snapshot..."
    fi
    
    # Always drop and recreate to avoid conflicts
    echo "Publishing snapshot $snapshot_name as $artifact_distro with GPG signing..."
    if aptly publish show "$artifact_distro" >/dev/null 2>&1; then
        echo "Dropping existing publication for $artifact_distro..."
        aptly publish drop "$artifact_distro" 2>/dev/null || true
    fi
    
    # Create new publication with GPG signing
    echo "Creating new signed publication for $artifact_distro..."
    
    if [ ! -z "$GPG_KEY_ID" ]; then
        echo "Using GPG key: $GPG_KEY_ID"
        echo "Executing: aptly publish snapshot -distribution=$artifact_distro -gpg-key=$GPG_KEY_ID $snapshot_name ."
        aptly publish snapshot -distribution="$artifact_distro" -gpg-key="$GPG_KEY_ID" "$snapshot_name" .
    else
        echo "Executing: aptly publish snapshot -distribution=$artifact_distro $snapshot_name ."
        aptly publish snapshot -distribution="$artifact_distro" "$snapshot_name" .
    fi
    
    echo "Signed publication for $artifact_distro created successfully!"
}

# Main processing loop for artifacts
DISTRO_DIRS="/data/packages/*/"
found_distro=false

for dir in $DISTRO_DIRS; do
    if [ -d "$dir" ]; then
        distro=$(basename "$dir")
        echo "Processing artifacts for distribution: $distro"
        found_distro=true
        
        # Process artifacts for this distribution
        create_and_publish_artifacts "$distro"
    fi
done

if [ "$found_distro" = false ]; then
    echo "No distribution directories found in /data/packages/"
    echo "Please create directories like /data/packages/dist1/ and /data/packages/dist2/"
    echo "and place .deb files in them."
fi

echo ""
echo "Artifact snapshot update process completed!"
echo "Published repositories are now available at http://localhost/"

# Show all current publications
echo ""
echo "Current publications:"
aptly publish list 2>/dev/null || echo "No publications found"
