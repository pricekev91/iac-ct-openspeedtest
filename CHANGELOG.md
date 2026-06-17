# Changelog

## [v0.2.3] — 2026-06-17

### Changed
- Remove `ports` mapping — macvlan container is directly accessible on 192.168.1.5
- OpenSpeedTest nginx listens on port 3000 internally, no port forwarding needed

## [v0.2.2] — 2026-06-17

### Fixed
- Compose file now SCP'd to remote host before `docker compose` execution

## [v0.2.1] — 2026-06-17

### Fixed
- Correct Docker image name: `openspeedtest/latest:latest` (was `openspeedtest/openspeedtest`)

## [v0.2.0] — 2026-06-17

### Changed
- **macvlan networking**: Switched from bridge/NAT (`ports: 8080:8080`) to macvlan so the container has its own dedicated IP `192.168.1.5/24` on the LAN
- **Compose V2**: Replaced legacy `docker-compose` CLI with `docker compose` (plugin-based)
- **Deployment script**: Full rewrite — added `--init` (create macvlan network), `--nuke` (prompt to remove existing + redeploy), `--status` (check only)
- **Nuke-and-redeploy**: Script prompts user before removing existing container
- **Verification**: Added post-deploy checks (container status, IP assignment)
- **README.md**: Updated with architecture diagram, prerequisites, usage, and network details
- **CHANGELOG.md**: Created

### Technical Details
- macvlan network created with: `docker network create -d macvlan --subnet 192.168.1.0/24 --gateway 192.168.1.1 --opt parent=eth0 macvlan`
- Container gets static IP via `ipv4_address: 192.168.1.5` in compose file
- Network marked `external: true` in compose file (created outside compose)
