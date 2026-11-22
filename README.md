# KubernetesOps

A personal homelab repository for learning, experimenting with, and operating Kubernetes. It contains infrastructure configurations, application deployments, and notes from building a self-hosted environment.

> **Work in progress:** This is an evolving lab, not a production-ready reference implementation. Some configurations are experimental or intentionally kept for learning.

## Overview

The environment uses Kubernetes to orchestrate self-hosted services and experiments across multiple machines. Areas of focus include persistent storage, file sharing, networking, application availability, and repeatable operations.

## Technology and services

| Component | Purpose |
| --- | --- |
| **Kubernetes / RKE2** | Runs and coordinates containerized workloads across the homelab. |
| **Nextcloud** | Self-hosted file storage, synchronization, and collaboration. |
| **Immich** | Self-hosted photo and video management. |
| **NFS** | Shared filesystem access for workloads that need network-mounted storage. |
| **Samba** | File sharing with Windows and macOS clients. |
| **Longhorn** | Kubernetes persistent block storage and replication for suitable workloads. |
| **Argo CD** | GitOps-based management of Kubernetes applications. |

### Storage approach

Storage is an ongoing area of experimentation. NFS provides shared filesystem access, while Longhorn serves workloads that benefit from replicated Kubernetes block volumes. These solve different problems; neither automatically combines the capacity of separate NFS servers into a single pool.

The longer-term plan is to keep NFS exports on individual machines (Lunap, Diana, and Galaxia) and make the provisioned storage location explicit through separate StorageClasses.

### Applications and websites

- **Nextcloud:** Private file storage and collaboration.
- **Immich:** Photo and video library management.
- **Websites:** Explore container-image-based deployment for Saira's web portfolio and decide whether a self-hosted image registry is worthwhile.
- **Future experiments:** Explore a self-hosted LLM-assisted music migration workflow as part of reducing reliance on Spotify.

## TODO

### Storage and data safety

- [ ] Review and clean up network file shares to reduce the risk of accidental deletion of important data.
- [ ] Evaluate improved storage layouts, replication, and backup/recovery practices.
- [ ] Document which workloads should use NFS versus Longhorn.

### NFS provisioner refactor

- [ ] Manage all three NFS provisioners through **one Argo CD multi-source Application**, using the official `nfs-subdir-external-provisioner` Helm chart three times—**no custom umbrella chart**.
- [ ] Configure separate provisioner identities and StorageClasses for **Lunap**, **Diana**, and **Galaxia**.
- [ ] Confirm each NFS Service address and exported path before deployment.
- [ ] Add Alpine debug sidecars if the chart supports them; otherwise document an ephemeral debug-container workflow.
- [ ] Check shared RBAC and cluster-scoped resource naming for collisions.
- [ ] Plan migration carefully so existing PVs, PVCs, and backing directories are not accidentally deleted or orphaned.

### Applications and documentation

- [ ] Document Immich configuration and storage considerations.
- [ ] Document the website deployment approach and container image hosting decision.
- [ ] Investigate the feasibility of an LLM-assisted music migration workflow.
- [x] Choose a domain for hosting services: **moonlightgrove.love** (rather than relying on GitHub Pages).

## Notes

This repository doubles as an operations notebook. Expect experiments, configuration revisions, and occasional commented-out code while the infrastructure evolves.
