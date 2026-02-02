# Mithril - Copilot Instructions

This project is a Docker-based DNS filtering solution for blocking adult content on your network, forked from pi-hole/docker-pi-hole.

## Project Structure

- `src/` - Source files for building the Docker image
  - `Dockerfile` - Multi-stage build for the Mithril image
  - `bash_functions.sh` - Helper functions including adult content blocklist setup
  - `start.sh` - Container entrypoint script
  - `crontab.txt` - Scheduled tasks for blocklist updates
- `build.sh` - Script to build the Docker image locally
- `docker-compose.yml` - Easy deployment configuration
- `examples/` - Example configurations

## Key Modifications from Pi-hole

1. Default blocklists changed from ad-blocking to adult content blocking
2. Branding updated to "Mithril"
3. Pre-configured for safe DNS filtering

## Building

```bash
./build.sh
```

## Running

```bash
docker compose up -d
```

## Technology Stack

- Base: Alpine Linux 3.22
- DNS: Pi-hole FTL (FTLDNS)
- Web Interface: Pi-hole Web Admin
