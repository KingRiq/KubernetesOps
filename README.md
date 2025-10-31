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

ADD Immich




Immich



Websites
Saira's Web Portfolio websites which should be completely deployed from a docker image of some sort. Should I host my own images? Find out on the next episode!
---

### Kubernetes
Kubernetes runs the **Nextcloud and Immich applications** and manages its pods, services, and scaling.  
It provides orchestration so workloads can move around nodes while maintaining availability.  

---

### NFS
An **NFS server inside the cluster** provides a **shared storage back**

Samba is used as a file share for compatibility across multiple windows and mac machines


Talk about NFS Provisioner -> Eventually will switch to CNI and use longhorn for replication... but what?

Potentally will host an LLM for musi transferring. Need to get rid of spotify but not real solution exists.