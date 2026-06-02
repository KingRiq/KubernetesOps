#!/usr/bin/env bash
set -e

# This script assumes sudo
# Mount HDD for slow storage
# TODO: convert to Ansible

LABEL=CC
DEVICE=/dev/sda1
SHARE=/mnt/windows/share
MOUNTPOINT=$SHARE/Chaos_Cauldron

# Unmount udisks automount (ignore failure)
umount -lf /run/media/rocky9/easystore 2>/dev/null || true

# Label XFS (must be unmounted)
xfs_admin -L "$LABEL" "$DEVICE"

# Create mount point
mkdir -p "$MOUNTPOINT"
chown root:root "$MOUNTPOINT"
chmod 775 "$MOUNTPOINT"

# Add fstab entry only if missing
grep -q "LABEL=$LABEL" /etc/fstab || \
echo "LABEL=$LABEL  $MOUNTPOINT  xfs  defaults,noatime,nofail  0  0" | tee -a /etc/fstab

# Reload systemd mount units
systemctl daemon-reload

# Mount
mount -a

# Verify
findmnt "$MOUNTPOINT"
ls -lah "$MOUNTPOINT"
