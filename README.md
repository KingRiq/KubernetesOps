# KubernetesOps

This repository is my sandbox for gaining familiarity with **Kubernetes**.  
Expect plenty of commented-out code and experiments while I refine things — I’ll be cleaning it up as I learn more.  

---

## TODO
- [ ] Think of a proper website (I don’t want to host on GitHub Pages — that feels too limited).  

---

## Technology Overview

### Nextcloud
[Nextcloud](https://nextcloud.com/) is an open-source, self-hosted **cloud storage and collaboration platform**.  
It’s often described as a private alternative to Google Drive, OneDrive, or Dropbox — but you run it on your own server.  

Key features:
- File storage and sync → store files, photos, and documents, and access them from desktops, browsers, or mobile apps.  

---

### Kubernetes
Kubernetes runs the **Nextcloud application** and manages its pods, services, and scaling.  
It provides orchestration so workloads can move around nodes while maintaining availability.  

---

### NFS
An **NFS server inside the cluster** provides a **shared storage back**
