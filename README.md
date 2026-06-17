# iac-ct-openspeedtest

Infrastructure as Code for OpenSpeedTest on HLH-Docker (Proxmox LXC 102).

## Overview

Deploys [OpenSpeedTest](https://www.openspeedtest.com/) as a Docker container on `hlh-docker` (192.168.1.13) using **macvlan networking** so the container has its own dedicated public IP (`192.168.1.5/24`) on the LAN.

## Architecture

```
+-----------------------------------------------+
|  Proxmox VE (192.168.1.10)                    |
|  +-- LXC 102 (hlh-docker) 192.168.1.13       |
|  |    Docker Engine + compose plugin           |
|  |    +-- macvlan network (parent=eth0)       |
|  |    |    +-- openspeedtest (192.168.1.5)    |
|  |    +-- dockhand (192.168.1.13:80)          |
+-----------------------------------------------+
                     |
              192.168.1.0/24 LAN
```

## Prerequisites

- SSH key auth to `root@192.168.1.13` (hlh-docker LXC)
- Docker Engine + compose plugin installed on hlh-docker
- macvlan network created (run `--init` first time)

## Usage

```bash
# First time: create the macvlan network
./deploy-iac-ct-openspeedtest.sh --init

# Deploy OpenSpeedTest
./deploy-iac-ct-openspeedtest.sh

# Nuke existing container and redeploy
./deploy-iac-ct-openspeedtest.sh --nuke

# Check container status
./deploy-iac-ct-openspeedtest.sh --status
```

## Files

| File | Purpose |
|------|---------|
| `openspeedtest-docker-compose.yml` | Docker compose config (macvlan, static IP) |
| `deploy-iac-ct-openspeedtest.sh` | Main deployment script |
| `configure-iac-ct-openspeedtest.sh` | Configuration script (placeholder) |
| `docker-compose.yml` | Placeholder — main config uses `openspeedtest-docker-compose.yml` |

## Network Details

- **Container name:** `openspeedtest`
- **MACVLAN parent:** `eth0` (on hlh-docker)
- **Static IP:** `192.168.1.5/24`
- **Gateway:** `192.168.1.1`
- **Port:** `80` (HTTP via `CHANGE_CONTAINER_PORTS` environment variable)

## Future

This macvlan setup is designed to coexist with other services that will each get their own IP:
- DNS server (next target)
- Additional web services
