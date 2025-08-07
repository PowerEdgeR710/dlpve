# dlpve - quick proxmox install script

This is basically Proxmox’s docs, but wrapped in an install script designed for quick deployment. You want something fast? Like uhhhhhh? iPXE but for Proxmox? This is it.

The script sets hostname, picks the fastest mirror, nukes cloud-init and Debian kernels, sets up a NAT bridge, installs Proxmox VE, DHCP server, and configures port forwarding for easy web UI access.

Run it on a fresh Debian install and get your Proxmox VE up and running.

---

**Usage:**

```bash
wget -qO- https://raw.githubusercontent.com/PowerEdgeR710/dlpve/refs/heads/main/install.sh | bash
```
OR
```bash
wget -qO- https://raw.githubusercontent.com/PowerEdgeR710/dlpve/refs/heads/main/install.sh | SKIP_HOSTNAME=true bash
```

`SKIP_HOSTNAME=true` skips hostname prompt, uses current hostname.

---

**Features:**

* Auto-detects main ethernet interface and IP
* Sets hostname and updates `/etc/hosts`
* Picks fastest Proxmox repo mirror
* Removes conflicting packages (cloud-init, Debian kernels)
* Configures NAT bridge (vmbr0) with IP forwarding
* Installs Proxmox VE and DHCP server
* Sets up systemd service to forward port 443 to 8006 (Proxmox web UI)

---

Access your new Proxmox web UI at:

* `https://<detected-ip>:8006`
* or `https://<detected-ip>:443`

---

Made by https://discord.gg/compute owner
