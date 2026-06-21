#!/usr/bin/env bash
set -euo pipefail

LABEL="CC"
DEVICE="/dev/disk/by-id/usb-WD_easystore_264D_43413032534D3947-0:0-part1"
SHARE="/mnt/windows/share"
MOUNTPOINT="$SHARE/Chaos_Cauldron"

echo "=== Checking stable WD easystore path ==="

if [ ! -e "$DEVICE" ]; then
  echo "ERROR: Expected drive not found:"
  echo "  $DEVICE"
  echo
  echo "Available by-id devices:"
  ls -lah /dev/disk/by-id/
  exit 1
fi

REAL_DEVICE="$(readlink -f "$DEVICE")"

echo "Using device: $DEVICE"
echo "Currently resolves to: $REAL_DEVICE"
echo

lsblk -f "$REAL_DEVICE"
echo

echo "=== Checking filesystem type ==="

FSTYPE="$(blkid -s TYPE -o value "$REAL_DEVICE" 2>/dev/null || true)"

if [ "$FSTYPE" != "xfs" ]; then
  echo "ERROR: $REAL_DEVICE is not XFS. Detected: ${FSTYPE:-none}"
  blkid "$REAL_DEVICE" || true
  exit 1
fi

echo "$REAL_DEVICE is XFS."
echo

echo "=== Unmounting old mounts ==="

if findmnt -rn "$MOUNTPOINT" >/dev/null 2>&1; then
  echo "Unmounting existing mountpoint: $MOUNTPOINT"
  umount -lf "$MOUNTPOINT" || true
fi

while read -r MNT; do
  if [ -n "$MNT" ]; then
    echo "Unmounting $MNT"
    umount -lf "$MNT" || true
  fi
done < <(findmnt -rn -S "$REAL_DEVICE" -o TARGET || true)

echo

echo "=== Preparing mount point ==="

mkdir -p "$MOUNTPOINT"
chown root:root "$MOUNTPOINT"
chmod 775 "$MOUNTPOINT"

echo "Mount point: $MOUNTPOINT"
echo

echo "=== Setting XFS label if needed ==="

CURRENT_LABEL="$(blkid -s LABEL -o value "$REAL_DEVICE" 2>/dev/null || true)"

if [ "$CURRENT_LABEL" != "$LABEL" ]; then
  echo "Setting XFS label to $LABEL on $REAL_DEVICE"
  xfs_admin -L "$LABEL" "$REAL_DEVICE"
else
  echo "Label already set to $LABEL"
fi

echo

echo "=== Updating /etc/fstab ==="

sed -i "\|[[:space:]]$MOUNTPOINT[[:space:]]|d" /etc/fstab
sed -i "\|LABEL=$LABEL[[:space:]]|d" /etc/fstab
sed -i "\|/dev/sd[a-z][0-9][[:space:]]$MOUNTPOINT[[:space:]]|d" /etc/fstab

echo "$DEVICE  $MOUNTPOINT  xfs  defaults,noatime,nofail,nouuid  0  0" >> /etc/fstab

systemctl daemon-reload

echo "New fstab entry:"
grep "$MOUNTPOINT" /etc/fstab
echo

echo "=== Mounting drive ==="

if ! mount "$MOUNTPOINT"; then
  echo
  echo "ERROR: Mount failed."
  echo "Recent kernel messages:"
  dmesg -T | tail -100
  exit 1
fi

echo

echo "=== Verifying mount ==="

findmnt "$MOUNTPOINT"
echo

echo "=== Contents ==="
ls -lah "$MOUNTPOINT"

echo
echo "SUCCESS: $DEVICE is mounted at $MOUNTPOINT"