
#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Chaos Cauldron Multi-Drive Mount Setup
# Rocky Linux 9
# ==========================================

# Ordered configuration: parent drive first.
LABELS=("CC" "APPLE")

MOUNTPOINTS=(
    "/mnt/windows/share/Chaos_Cauldron"
    "/mnt/windows/share/Chaos_Cauldron/Apple"
)

echo "=========================================="
echo " Chaos Cauldron XFS Mount Setup"
echo "=========================================="

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run as root."
    exit 1
fi

# ==========================================
# Preflight: Resolve and validate both drives
# ==========================================

declare -a DEVICES UUIDS

for i in "${!LABELS[@]}"; do
    LABEL="${LABELS[$i]}"
    MP="${MOUNTPOINTS[$i]}"

    DEVICE="$(blkid -L "$LABEL" 2>/dev/null || true)"

    if [[ -z "$DEVICE" ]]; then
        echo "ERROR: Cannot find drive labeled $LABEL"
        lsblk -f
        exit 1
    fi

    DEVICE="$(readlink -f "$DEVICE")"
    FSTYPE="$(blkid -s TYPE -o value "$DEVICE" || true)"
    UUID="$(blkid -s UUID -o value "$DEVICE" || true)"

    if [[ "$FSTYPE" != "xfs" || -z "$UUID" ]]; then
        echo "ERROR: $LABEL must be an XFS filesystem with a UUID."
        exit 1
    fi

    DEVICES[$i]="$DEVICE"
    UUIDS[$i]="$UUID"

    echo "$LABEL: $DEVICE -> $MP"
    echo "UUID: $UUID"
done

if [[ "${UUIDS[0]}" == "${UUIDS[1]}" ]]; then
    echo "ERROR: Both drives have the same filesystem UUID."
    exit 1
fi

# ==========================================
# Mount helper
# ==========================================

mount_drive() {
    local LABEL="$1"
    local DEVICE="$2"
    local UUID="$3"
    local MP="$4"

    echo
    echo "=========================================="
    echo " Processing $LABEL"
    echo "=========================================="

    mkdir -p "$MP"

    # Check if already mounted at target
    local CURRENT_UUID
    CURRENT_UUID="$(
        findmnt -rn -M "$MP" -o UUID 2>/dev/null || true
    )"

    if mountpoint -q "$MP"; then
        if [[ "$CURRENT_UUID" != "$UUID" ]]; then
            echo "ERROR: Wrong filesystem mounted at $MP"
            exit 1
        fi
        echo "$LABEL already mounted correctly."
    else
        # Don't hide existing files
        if [[ -n "$(find "$MP" -mindepth 1 -maxdepth 1 \
            -print -quit)" ]]; then
            echo "ERROR: Mountpoint contains files:"
            ls -lah "$MP"
            exit 1
        fi

        # Don't mount the same drive in two places
        local OTHER_MOUNTS
        OTHER_MOUNTS="$(
            findmnt -rn -S "$DEVICE" -o TARGET 2>/dev/null || true
        )"

        if [[ -n "$OTHER_MOUNTS" ]]; then
            echo "ERROR: $LABEL is already mounted at:"
            echo "$OTHER_MOUNTS"
            exit 1
        fi
    fi

    # Mount if not already mounted
    if ! mountpoint -q "$MP"; then
        echo "Mounting $LABEL..."
        mount -t xfs -o defaults,noatime "$DEVICE" "$MP"
    fi

    # Verify UUID
    CURRENT_UUID="$(
        findmnt -rn -M "$MP" -o UUID 2>/dev/null || true
    )"

    if [[ "$CURRENT_UUID" != "$UUID" ]]; then
        echo "ERROR: Mount verification failed for $LABEL"
        exit 1
    fi

    echo "SUCCESS: $LABEL"
    findmnt -M "$MP"
    df -h "$MP"
}

# ==========================================
# Mount parent, then child
# ==========================================

for i in "${!LABELS[@]}"; do
    mount_drive \
        "${LABELS[$i]}" \
        "${DEVICES[$i]}" \
        "${UUIDS[$i]}" \
        "${MOUNTPOINTS[$i]}"
done

# ==========================================
# Update /etc/fstab after successful mounts
# ==========================================

echo
echo "=== Updating /etc/fstab ==="

BACKUP="/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
cp -a /etc/fstab "$BACKUP"

TEMP="$(mktemp)"
trap 'rm -f "$TEMP"' EXIT

# Remove previous entries for either mountpoint,
# UUID, label, or resolved device.
awk \
    -v mp1="${MOUNTPOINTS[0]}" \
    -v mp2="${MOUNTPOINTS[1]}" \
    -v uuid1="UUID=${UUIDS[0]}" \
    -v uuid2="UUID=${UUIDS[1]}" \
    -v label1="LABEL=${LABELS[0]}" \
    -v label2="LABEL=${LABELS[1]}" \
    -v dev1="${DEVICES[0]}" \
    -v dev2="${DEVICES[1]}" '
    $2 == mp1 || $2 == mp2 { next }
    $1 == uuid1 || $1 == uuid2 { next }
    $1 == label1 || $1 == label2 { next }
    $1 == dev1 || $1 == dev2 { next }
    { print }
' /etc/fstab > "$TEMP"

# Parent mount
printf 'UUID=%s %s xfs defaults,noatime,nofail 0 0\n' \
    "${UUIDS[0]}" "${MOUNTPOINTS[0]}" >> "$TEMP"

# Child mount explicitly depends on parent
printf 'UUID=%s %s xfs defaults,noatime,nofail,x-systemd.requires-mounts-for=%s 0 0\n' \
    "${UUIDS[1]}" "${MOUNTPOINTS[1]}" \
    "${MOUNTPOINTS[0]}" >> "$TEMP"

# Validate fstab before replacing it
if ! findmnt --verify --tab-file "$TEMP"; then
    echo "ERROR: fstab validation failed."
    echo "Original fstab remains unchanged."
    exit 1
fi

cat "$TEMP" > /etc/fstab
systemctl daemon-reload

echo "fstab backup: $BACKUP"

# ==========================================
# Final verification
# ==========================================

echo
echo "=========================================="
echo " Final Mount Verification"
echo "=========================================="

for i in "${!LABELS[@]}"; do
    LABEL="${LABELS[$i]}"
    MP="${MOUNTPOINTS[$i]}"
    UUID="${UUIDS[$i]}"

    ACTUAL_UUID="$(
        findmnt -rn -M "$MP" -o UUID 2>/dev/null || true
    )"

    if [[ "$ACTUAL_UUID" != "$UUID" ]]; then
        echo "ERROR: $LABEL verification failed."
        exit 1
    fi

    echo
    echo "Label: $LABEL"
    echo "UUID:  $UUID"
    findmnt -M "$MP"
    df -h "$MP"
done

echo
echo "=========================================="
echo " SUCCESS - BOTH DRIVES MOUNTED"
echo "=========================================="

echo
echo "CC:    ${MOUNTPOINTS[0]}"
echo "Apple: ${MOUNTPOINTS[1]}"
echo
