#!/bin/bash
set -e

echo "Starting artifact snapshot update process..."

# Get the GPG key ID for signing (works for both imported and generated keys,
# since either way the key lives in the container's keyring).
GPG_KEY_ID=$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec:/{print $5; exit}')

# Refuse to publish unsigned: clients configured per the docs verify signatures,
# so an unsigned publish would break every `apt update` against this repo.
if [ -z "$GPG_KEY_ID" ]; then
    echo "ERROR: no GPG secret key found in the container keyring; cannot sign."
    echo "Restart the container to (re)import the key from /data/gpg/private.key."
    exit 1
fi

# Snapshot retention: how many of the most-recent snapshots to keep per
# distribution after each publish. 0 keeps every snapshot forever. Override via
# the SNAPSHOT_RETENTION environment variable (e.g. in docker-compose.yml).
SNAPSHOT_RETENTION="${SNAPSHOT_RETENTION:-5}"
case "$SNAPSHOT_RETENTION" in
    ''|*[!0-9]*)
        echo "WARN: SNAPSHOT_RETENTION='$SNAPSHOT_RETENTION' is not a non-negative integer; keeping all snapshots."
        SNAPSHOT_RETENTION=0
        ;;
esac
if [ "$SNAPSHOT_RETENTION" -eq 0 ]; then
    echo "Snapshot retention: keeping all snapshots (SNAPSHOT_RETENTION=0)."
else
    echo "Snapshot retention: keeping the $SNAPSHOT_RETENTION most recent snapshot(s) per distribution."
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
    
    # Import new .deb files. Identify packages by their control-file metadata
    # (package_version_arch), not the filename, so renamed files are still
    # deduplicated correctly against the repo's package list.
    echo "Checking for new .deb files in $deb_dir..."
    local repo_packages
    repo_packages=$(aptly repo show -with-packages "local-$distro")
    find "$deb_dir" -name "*.deb" -type f | while read deb_file; do
        pkg_key=$(dpkg-deb --show --showformat '${Package}_${Version}_${Architecture}' "$deb_file" 2>/dev/null || true)
        if [ -n "$pkg_key" ] && echo "$repo_packages" | grep -qF "$pkg_key"; then
            echo "$(basename "$deb_file") ($pkg_key) already imported, skipping..."
        else
            echo "Importing $(basename "$deb_file") into local-$distro..."
            aptly repo add "local-$distro" "$deb_file"
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
    echo "Creating new signed publication for $artifact_distro using key $GPG_KEY_ID..."
    aptly publish snapshot -distribution="$artifact_distro" -gpg-key="$GPG_KEY_ID" "$snapshot_name" .

    echo "Signed publication for $artifact_distro created successfully!"

    # Apply snapshot retention: keep the N most recent snapshots for this distro
    # (names embed a sortable YYYYMMDD_HHMMSS timestamp), drop the rest. Skipped
    # entirely when retention is 0 (keep forever). The just-published snapshot is
    # always among the newest and is protected from dropping regardless.
    if [ "$SNAPSHOT_RETENTION" -gt 0 ]; then
        aptly snapshot list -raw 2>/dev/null | grep "^${distro}-artifacts-snapshot-" \
            | sort -r | tail -n +"$((SNAPSHOT_RETENTION + 1))" | \
        while read old_snapshot; do
            [ "$old_snapshot" = "$snapshot_name" ] && continue
            echo "Dropping snapshot $old_snapshot (beyond retention of $SNAPSHOT_RETENTION)..."
            aptly snapshot drop "$old_snapshot" 2>/dev/null || true
        done
    fi
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

# Reclaim space from dropped snapshots and unreferenced packages.
echo ""
echo "Cleaning up aptly database..."
aptly db cleanup

echo ""
echo "Artifact snapshot update process completed!"
echo "Published repositories are now available at http://localhost/"

# Show all current publications
echo ""
echo "Current publications:"
aptly publish list 2>/dev/null || echo "No publications found"
