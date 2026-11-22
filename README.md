# KubernetesOps

**A personal Kubernetes homelab, built and maintained as a learning environment.**

This repository contains Ansible automation, RKE2 cluster operations, storage tooling, and the bootstrap configuration for a self-hosted Kubernetes environment.

> [!NOTE]
> This is an evolving homelab, not a production deployment guide. The repositories contain active configuration, experiments, legacy manifests, and planned integrations. A manifest in Git does **not** necessarily mean the service is currently deployed or healthy.

## Architecture at a glance

| Layer | Technologies | Role |
| --- | --- | --- |
| Hosts and OS | **Rocky Linux 9**, bare-metal mini PCs | Cluster hosts and local disks |
| Kubernetes | **RKE2**, **etcd** | Cluster orchestration and control-plane state |
| Automation | **Ansible**, **Helm** | Host setup, cluster bootstrap, and package deployment |
| GitOps | **Argo CD** | Declarative application deployment and reconciliation |
| Networking | **Calico / Canal**, **MetalLB**, **kube-vip** | Pod networking, LoadBalancer IPs, and API endpoint availability |
| Ingress and routing | **Traefik**, **Istio**, **Istio Ingress**; Nginx manifests (historical) | HTTP(S) ingress and traffic routing |
| DNS and TLS | **Pi-hole**, **cert-manager**, **Let's Encrypt** | Local DNS, certificates, and service discovery |
| Remote connectivity | **Tailscale** | Private remote access |
| Storage | **Longhorn**, **NFS**, **Samba**, **XFS** | Persistent volumes, shared files, and host disks |
| Observability | **Prometheus**, **Grafana**, **Loki** | Metrics, dashboards, and logs |
| Delivery and source control | **Gitea**, **Jenkins** | Git hosting and CI automation |

### Cluster operations

The cluster is organized around multiple RKE2 control-plane and worker nodes. Ansible manages node setup and lifecycle operations, including promotion, demotion, installation, removal, and supporting host configuration. Helm and Argo CD handle much of the Kubernetes-side deployment.

The cluster configuration lives under [`ansible-rke2/`](ansible-rke2/).

## Self-hosted services

The screenshots provided on **November 21, 2026** show **23 Argo CD Applications**. The table below summarizes the broader stack; some entries are components within an Application, while others are experiments or repository configurations. The screenshots reflect a point-in-time status, not ongoing health monitoring.

| Category | Services | Purpose |
| --- | --- | --- |
| Cloud and photos | **Nextcloud**, **Immich** | Personal file synchronization and photo/video management |
| Media | **Jellyfin**, **Komga** | Streaming and reading libraries |
| Media automation | **Sonarr**, **Radarr**, **Bazarr**, **Prowlarr**, **qBittorrent**, **Seerr / Overseerr**, **FlareSolverr** | Library management, downloads, indexing, and requests |
| Developer tooling | **Gitea**, **Jenkins** | Git repositories and automated builds |
| Files and synchronization | **File Browser**, **Syncthing**, **Unison** (experimental) | File management and synchronization between storage hosts |
| Identity and secrets | **Keycloak** (experimental), **Vaultwarden** | Identity experiments and password management |
| Infrastructure UI | **Rancher** (deployed in Argo CD) | Kubernetes administration |
| DNS and networking | **Pi-hole**, **Tailscale**, **Traefik** | DNS, private connectivity, and ingress |
| Platform maintenance | **Descheduler**, **Reloader** | Scheduling and configuration-change automation |

### Cluster software and services

The following table describes the applications and platform components used in the homelab and the capabilities they provide. It is a functional inventory, not a live deployment or health report.

| Software | Role in the cluster |
| --- | --- |
| **Argo CD** | GitOps reconciliation and declarative deployment of Kubernetes applications |
| **Arrstack** (Sonarr, Radarr, Bazarr, Prowlarr, Seerr / Overseerr, FlareSolverr) | Media discovery, indexing, subtitles, and library/request automation |
| **File Browser** | Web-based browsing and management of shared files |
| **Galaxia** | Cluster-specific utility workloads and supporting configuration |
| **Gitea** | Self-hosted Git repositories and source control |
| **Immich** | Self-hosted photo and video backup, organization, and search |
| **Istio** | Service-mesh control plane, traffic policy, and custom resource definitions |
| **Istio Ingress** | Istio ingress gateway and routing of incoming traffic |
| **Jellyfin** | Media streaming |
| **Jenkins** | Continuous integration and build automation |
| **Komga** | Manga and comics library server |
| **Longhorn** | Replicated Kubernetes block storage and volume backups |
| **Maintenance** | Cluster maintenance and scheduling utilities |
| **Nextcloud** | Personal file hosting and synchronization |
| **NFS** | Shared network filesystem exports for workloads |
| **NFS Subdir External Provisioner** | Dynamic provisioning of Kubernetes persistent volumes on NFS exports |
| **Pi-hole** | Network DNS filtering and local DNS records |
| **Rancher** | Kubernetes cluster administration interface |
| **Reloader** | Restarting workloads when referenced ConfigMaps or Secrets change |
| **Tailscale** | Private remote network connectivity |
| **Traefik** | Reverse proxy and Kubernetes ingress routing |
| **Vaultwarden** | Self-hosted password manager compatible with Bitwarden clients |

## Storage design

Storage is one of the main ongoing projects.

- **Longhorn:** Kubernetes-managed block storage for persistent application data, with replica placement and NFS-based backup targets.
- **NFS:** Shared network filesystems for workloads needing file access across pods and nodes.
- **NFS subdirectory external provisioner:** Creates per-claim directories on a configured NFS export; each provisioner instance targets one backend.
- **Samba:** SMB shares for Windows and macOS clients.
- **XFS:** Filesystem used on attached host storage.
- **Syncthing / Unison:** Explored for cross-host file synchronization; synchronization is not the same as a unified distributed filesystem.

The goal is to simplify storage consumption without sacrificing visibility into where data lives, while keeping deletion and recovery behavior predictable.

## Repository layout

```text
KubernetesOps/
├── README.md
└── ansible-rke2/
    ├── inventory/         # Cluster hosts and groups
    ├── group_vars/        # Shared Ansible variables
    ├── roles/             # RKE2 and infrastructure roles
    ├── rke2.yml           # Main cluster playbook
    ├── promote.yml        # Control-plane promotion
    ├── demote.yml         # Control-plane demotion
    ├── remove_worker.yml  # Worker lifecycle
```

## Roadmap and TODOs

### Storage and safety

- [ ] Audit NFS/SMB exports, mounts, and deletion behavior to reduce the risk of accidental data loss.
- [ ] Improve backup, restore, and disaster-recovery documentation for NFS and Longhorn.
- [ ] Document storage selection criteria for application configs, databases, and media.
- [ ] Evaluate approaches to cross-host storage access and synchronization without assuming they form one shared pool.

### Consolidate NFS provisioning under one Argo CD Application

- [ ] Use **one Argo CD multi-source Application** referencing the official `nfs-subdir-external-provisioner` Helm chart **three times**, without building an umbrella chart.
- [ ] Configure independent provisioners and StorageClasses for **Lunap**, **Diana**, and **Galaxia**.
- [ ] Verify actual NFS Service endpoints and export paths.
- [ ] Assess Alpine debug sidecars or ephemeral debug containers.
- [ ] Check release naming and cluster-scoped RBAC for collisions.
- [ ] Protect existing PVs/PVCs and backing directories during migration.

### Documentation and experiments

- [ ] Document service ownership, dependencies, and recovery steps.
- [ ] Document the Immich and Nextcloud data paths and database recovery processes.
- [ ] Explore container-image deployment for Saira's portfolio websites and whether a private image registry is needed.
- [ ] Investigate an LLM-assisted music migration workflow.
- [x] Select a domain for self-hosted services: **moonlightgrove.love**.

---

*Built to learn, experiment, break things safely, and improve the next iteration.*
