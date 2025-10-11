sudo systemctl stop rke2-agent kubelet containerd 2>/dev/null || true
# kill any lingering shims that may hold mounts
pgrep -f "containerd-shim.*k8s" | xargs -r sudo kill -9


# Unmount anything under /var/lib/kubelet/pods
sudo cat /proc/self/mountinfo \
 | awk '$5 ~ "^/var/lib/kubelet/pods" {print $5}' \
 | sort -r \
 | while read -r m; do sudo umount -l "$m" || true; done

# Also unmount kubelet's runtime/netns leftovers if present
sudo cat /proc/self/mountinfo \
 | awk '$5 ~ "^/run/k3s" || $5 ~ "^/run/netns" {print $5}' \
 | sort -r \
 | while read -r m; do sudo umount -l "$m" || true; done

# List remaining NFS mounts under pods
mount | awk '$5=="nfs" && $3 ~ "^/var/lib/kubelet/pods" {print $3}' | sort -r

# Force + lazy (NFS supports -f)
for m in $(mount | awk '$5=="nfs" && $3 ~ "^/var/lib/kubelet/pods" {print $3}' | sort -r); do
  sudo umount -f -l "$m" || true
done

findmnt -R /var/lib/kubelet/pods || echo "No remaining mounts under /var/lib/kubelet/pods"


