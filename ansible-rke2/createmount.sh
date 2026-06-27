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

echo "Using by-id device: $DEVICE"
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

echo "=== Getting filesystem UUID ==="

UUID="$(blkid -s UUID -o value "$REAL_DEVICE" 2>/dev/null || true)"

if [ -z "$UUID" ]; then
  echo "ERROR: No UUID found on $REAL_DEVICE"
  blkid "$REAL_DEVICE" || true
  exit 1
fi

echo "UUID: $UUID"
echo

echo "=== Checking for duplicate UUIDs ==="

mapfile -t UUID_MATCHES < <(blkid -t UUID="$UUID" -o device 2>/dev/null | sort -u || true)

if [ "${#UUID_MATCHES[@]}" -gt 1 ]; then
  echo "ERROR: More than one block device has UUID=$UUID"
  echo "This is unsafe for UUID mounting:"
  printf '  %s\n' "${UUID_MATCHES[@]}"
  echo
  echo "Do not continue until the duplicate UUID problem is fixed."
  exit 1
fi

echo "UUID is unique."
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

echo "=== Updating /etc/fstab to use UUID ==="

FSTAB_BACKUP="/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
cp -a /etc/fstab "$FSTAB_BACKUP"
echo "Backed up /etc/fstab to: $FSTAB_BACKUP"

TMP_FSTAB="$(mktemp)"

awk \
  -v mp="$MOUNTPOINT" \
  -v uuid="UUID=$UUID" \
  -v label="LABEL=$LABEL" \
  -v dev="$DEVICE" \
  -v real="$REAL_DEVICE" '
  /^[[:space:]]*#/ {
    print
    next
  }

  NF == 0 {
    print
    next
  }

  $2 == mp {
    next
  }

  $1 == uuid {
    next
  }

  $1 == label {
    next
  }

  $1 == dev {
    next
  }

  $1 == real {
    next
  }

  {
    print
  }
' /etc/fstab > "$TMP_FSTAB"

cat "$TMP_FSTAB" > /etc/fstab
rm -f "$TMP_FSTAB"

echo "UUID=$UUID  $MOUNTPOINT  xfs  defaults,noatime,nofail  0  0" >> /etc/fstab

systemctl daemon-reload

echo
echo "New fstab entry:"
grep -F "$MOUNTPOINT" /etc/fstab
echo

echo "=== Mounting drive ==="

if ! mount "$MOUNTPOINT"; then
  echo
  echo "ERROR: Mount failed."
  echo "Restoring previous /etc/fstab from backup."
  cp -a "$FSTAB_BACKUP" /etc/fstab
  systemctl daemon-reload
  echo
  echo "Recent kernel messages:"
  dmesg -T | tail -100
  exit 1
fi

echo

echo "=== Verifying mount ==="

findmnt "$MOUNTPOINT"
echo

MOUNT_SOURCE="$(findmnt -rn "$MOUNTPOINT" -o SOURCE || true)"
MOUNT_SOURCE_REAL="$(readlink -f "$MOUNT_SOURCE" 2>/dev/null || echo "$MOUNT_SOURCE")"

echo "Mounted source: $MOUNT_SOURCE"
echo "Mounted source resolves to: $MOUNT_SOURCE_REAL"
echo "Expected device: $REAL_DEVICE"
echo

if [ "$MOUNT_SOURCE_REAL" != "$REAL_DEVICE" ]; then
  echo "WARNING: Mount source does not resolve to expected device."
  echo "This may be normal if findmnt reports UUID/LABEL mapper paths, but verify carefully."
fi

echo "=== Contents ==="
ls -lah "$MOUNTPOINT"

echo
echo "SUCCESS: UUID=$UUID is mounted at $MOUNTPOINT"