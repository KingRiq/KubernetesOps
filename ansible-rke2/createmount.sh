#!/usr/bin/env bash
set -euo pipefail

LABEL="CC"
MOUNTPOINT="/mnt/windows/share/Chaos_Cauldron"

echo "=========================================="
echo " Chaos Cauldron XFS Mount Setup"
echo "=========================================="
echo

#
# Find filesystem by LABEL
#
echo "=== Finding XFS drive ==="

DEVICE="$(blkid -L "$LABEL" 2>/dev/null || true)"

if [ -z "$DEVICE" ]; then
    echo "ERROR: Could not find filesystem labeled: $LABEL"
    echo
    echo "Available filesystems:"
    lsblk -f
    echo
    blkid || true
    exit 1
fi

REAL_DEVICE="$(readlink -f "$DEVICE")"

echo "Found:"
echo "  Label:  $LABEL"
echo "  Device: $DEVICE"
echo "  Real:   $REAL_DEVICE"
echo


#
# Verify filesystem
#
echo "=== Verifying filesystem ==="

FSTYPE="$(blkid -s TYPE -o value "$REAL_DEVICE" 2>/dev/null || true)"
UUID="$(blkid -s UUID -o value "$REAL_DEVICE" 2>/dev/null || true)"

if [ "$FSTYPE" != "xfs" ]; then
    echo "ERROR: Expected XFS but found: ${FSTYPE:-none}"
    exit 1
fi

if [ -z "$UUID" ]; then
    echo "ERROR: Could not determine filesystem UUID."
    exit 1
fi

echo "Filesystem: $FSTYPE"
echo "UUID:       $UUID"
echo


#
# Prepare mountpoint
#
echo "=== Preparing mountpoint ==="

mkdir -p "$MOUNTPOINT"

echo "Mountpoint:"
echo "  $MOUNTPOINT"
echo


#
# Determine whether something is mounted EXACTLY
# at the desired mountpoint.
#
echo "=== Checking current mount ==="

CURRENT_SOURCE="$(findmnt -rn -M "$MOUNTPOINT" -o SOURCE 2>/dev/null || true)"
CURRENT_UUID="$(findmnt -rn -M "$MOUNTPOINT" -o UUID 2>/dev/null || true)"

if [ -n "$CURRENT_SOURCE" ]; then

    echo "Something is already mounted here:"
    echo "  Source: $CURRENT_SOURCE"
    echo "  UUID:   ${CURRENT_UUID:-unknown}"
    echo

    #
    # Make sure it is OUR filesystem.
    #
    if [ "$CURRENT_UUID" != "$UUID" ]; then
        echo "ERROR: A different filesystem is mounted at:"
        echo "  $MOUNTPOINT"
        echo
        echo "Expected UUID:"
        echo "  $UUID"
        echo
        echo "Found UUID:"
        echo "  ${CURRENT_UUID:-unknown}"
        echo
        echo "Refusing to continue."
        exit 1
    fi

    echo "Correct filesystem is already mounted."

else

    echo "Nothing is currently mounted at:"
    echo "  $MOUNTPOINT"
    echo

    #
    # Check whether files accidentally exist in the
    # underlying directory on the root filesystem.
    #
    if [ -n "$(find "$MOUNTPOINT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then

        echo "ERROR: The mountpoint contains files while CC is NOT mounted."
        echo
        echo "These files are currently stored on the underlying"
        echo "root filesystem and would become hidden after mounting CC."
        echo
        echo "Contents:"
        echo

        ls -lah "$MOUNTPOINT"

        echo
        echo "Disk usage:"
        du -sh "$MOUNTPOINT" || true

        echo
        echo "Move/remove these files before running this script again."
        exit 1
    fi

    chmod 775 "$MOUNTPOINT"
fi

echo


#
# Check whether CC happens to already be mounted
# somewhere else.
#
echo "=== Checking for other mounts of CC ==="

OTHER_MOUNTS="$(findmnt -rn -S "$REAL_DEVICE" -o TARGET 2>/dev/null || true)"

if [ -n "$OTHER_MOUNTS" ]; then

    FOUND_EXPECTED="false"

    while IFS= read -r TARGET; do
        [ -z "$TARGET" ] && continue

        if [ "$TARGET" = "$MOUNTPOINT" ]; then
            FOUND_EXPECTED="true"
        else
            echo "ERROR: $REAL_DEVICE is already mounted somewhere else:"
            echo "  $TARGET"
            echo
            echo "Expected mountpoint:"
            echo "  $MOUNTPOINT"
            echo
            echo "Refusing to mount the filesystem twice."
            exit 1
        fi
    done <<< "$OTHER_MOUNTS"

fi

echo "No conflicting mounts found."
echo


#
# Update /etc/fstab
#
echo "=== Updating /etc/fstab ==="

FSTAB_BACKUP="/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

cp -a /etc/fstab "$FSTAB_BACKUP"

echo "Backup created:"
echo "  $FSTAB_BACKUP"
echo

FSTAB_TEMP="$(mktemp)"

#
# Remove:
#   - any existing entry using this mountpoint
#   - any existing entry using this filesystem UUID
#
awk \
    -v mp="$MOUNTPOINT" \
    -v uuid="UUID=$UUID" '
    $2 == mp { next }
    $1 == uuid { next }
    { print }
' /etc/fstab > "$FSTAB_TEMP"

#
# Add canonical entry
#
echo "UUID=$UUID  $MOUNTPOINT  xfs  defaults,noatime,nofail  0  0" >> "$FSTAB_TEMP"

cat "$FSTAB_TEMP" > /etc/fstab
rm -f "$FSTAB_TEMP"

systemctl daemon-reload

echo "fstab entry:"
echo "  UUID=$UUID  $MOUNTPOINT  xfs  defaults,noatime,nofail  0  0"
echo


#
# Mount filesystem
#
echo "=== Mounting ==="

CURRENT_SOURCE="$(findmnt -rn -M "$MOUNTPOINT" -o SOURCE 2>/dev/null || true)"
CURRENT_UUID="$(findmnt -rn -M "$MOUNTPOINT" -o UUID 2>/dev/null || true)"

if [ -n "$CURRENT_SOURCE" ]; then

    if [ "$CURRENT_UUID" = "$UUID" ]; then
        echo "Already mounted correctly:"
        echo "  $CURRENT_SOURCE -> $MOUNTPOINT"
    else
        echo "ERROR: Unexpected filesystem appeared at mountpoint."
        echo "Expected UUID: $UUID"
        echo "Found UUID:    ${CURRENT_UUID:-unknown}"
        exit 1
    fi

else

    echo "Mounting:"
    echo "  UUID=$UUID"
    echo "  -> $MOUNTPOINT"
    echo

    mount "$MOUNTPOINT"
fi

echo


#
# Final verification
#
echo "=== Verification ==="

MOUNTED_UUID="$(findmnt -rn -M "$MOUNTPOINT" -o UUID 2>/dev/null || true)"

if [ "$MOUNTED_UUID" != "$UUID" ]; then
    echo "ERROR: Mount verification failed."
    echo
    echo "Expected UUID:"
    echo "  $UUID"
    echo
    echo "Mounted UUID:"
    echo "  ${MOUNTED_UUID:-none}"
    exit 1
fi

findmnt "$MOUNTPOINT"

echo
echo "=== Disk Usage ==="

df -h "$MOUNTPOINT"

echo
echo "=== Contents ==="

ls -lah "$MOUNTPOINT"

echo
echo "=========================================="
echo " SUCCESS"
echo "=========================================="
echo
echo "Label:      $LABEL"
echo "Device:     $REAL_DEVICE"
echo "UUID:       $UUID"
echo "Filesystem: $FSTYPE"
echo "Mountpoint: $MOUNTPOINT"
echo