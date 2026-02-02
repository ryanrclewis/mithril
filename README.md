# Docker Mithril

[![License: EUPL](https://img.shields.io/badge/License-EUPL%201.2-blue.svg)](LICENSE)

<div align="center">
  <h3>⚔️ Mithril</h3>
  <strong>DNS-based NSFW content filter for your home network</strong>
  <br><br>
  <em>Forked from <a href="https://github.com/pi-hole/docker-pi-hole">pi-hole/docker-pi-hole</a></em>
</div>

---

## What is Mithril?

Mithril is a Docker-based DNS filtering solution that blocks NSFW content across your entire network. Built on the powerful Pi-hole platform, it uses curated blocklists specifically targeting NSFW websites to keep your home network safe and secure.

### Key Features

- 🚫 **NSFW Content Blocking** - Pre-configured with comprehensive NSFW content blocklists
- 🌐 **Network-Wide Protection** - Protects all devices on your network automatically
- 📊 **Web Dashboard** - Easy-to-use interface for monitoring and management
- 🔒 **Secure DNS** - Defaults to Cloudflare Family DNS (1.1.1.3) for additional protection
- 🐳 **Docker-Based** - Easy deployment and updates
- 📝 **Detailed Logging** - See what's being blocked and monitor network activity

## Quick Start

### Using Docker Compose (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ryanrclewis/docker-mithril.git
   cd docker-mithril
   ```

2. **Build the image:**
   ```bash
   ./build.sh
   ```

3. **Configure and start:**
   ```bash
   # Edit docker-compose.yml to set your password and timezone
   docker compose up -d
   ```

4. **Configure your network:**
   - Set your router's DNS to point to the Mithril IP address
   - Or configure individual devices to use Mithril as their DNS server

5. **Access the web interface:**
   - Open http://pi.hole/admin or http://YOUR_IP/admin
   - Login with the password you set (or check logs for random password)

### Quick Start with Pre-built Image

```yaml
# docker-compose.yml
services:
  mithril:
    container_name: mithril
    image: mithril:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
      - "443:443/tcp"
    environment:
      TZ: 'America/New_York'
      FTLCONF_webserver_api_password: 'your-secure-password'
      FTLCONF_dns_listeningMode: 'ALL'
    volumes:
      - './etc-pihole:/etc/pihole'
    restart: unless-stopped
```

## Pre-configured Blocklists

Mithril comes pre-configured with the following NSFW content blocklists:

| Blocklist | Description |
|-----------|-------------|
| [StevenBlack Unified + NSFW](https://github.com/StevenBlack/hosts) | Comprehensive hosts file with NSFW extension |
| [OISD NSFW](https://oisd.nl/) | Well-maintained, frequently updated NSFW list |
| [StevenBlack NSFW Extensions](https://github.com/StevenBlack/hosts) | Additional NSFW-blocking extensions |
| [Chad Mayfield's Top 1M](https://github.com/chadmayfield/my-pihole-blocklists) | Top 1 million NSFW sites |
| [Sinfonietta NSFW](https://github.com/Sinfonietta/hostfiles) | NSFW hosts file |
| [BigDargon HostsVN NSFW](https://github.com/bigdargon/hostsVN) | Vietnamese NSFW content list |
| [Energized NSFW](https://energized.pro/) | Energized protection NSFW list |

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Your timezone |
| `FTLCONF_webserver_api_password` | Random | Web interface password |
| `FTLCONF_dns_upstreams` | `1.1.1.3;1.0.0.3` | Upstream DNS servers |
| `FTLCONF_dns_listeningMode` | `local` | DNS listening mode (`ALL` for Docker bridge) |
| `PIHOLE_UID` | `1000` | User ID for pihole user |
| `PIHOLE_GID` | `1000` | Group ID for pihole group |

### Recommended Upstream DNS Servers

Mithril defaults to Cloudflare Family DNS, which provides additional NSFW content blocking at the resolver level:

| Provider | Primary | Secondary | Features |
|----------|---------|-----------|----------|
| **Cloudflare Family** | `1.1.1.3` | `1.0.0.3` | Malware + NSFW blocking |
| **CleanBrowsing Family** | `185.228.168.168` | `185.228.169.168` | NSFW + Proxies + VPNs |
| **OpenDNS FamilyShield** | `208.67.222.123` | `208.67.220.123` | NSFW content blocking |

To change upstream DNS, set the `FTLCONF_dns_upstreams` environment variable:

```yaml
environment:
  FTLCONF_dns_upstreams: '185.228.168.168;185.228.169.168'
```

## Managing Blocklists

### Adding Custom Blocklists

1. Access the web interface at http://pi.hole/admin
2. Navigate to **Adlists**
3. Add your blocklist URL
4. Run `docker exec mithril pihole -g` to update gravity

### Whitelisting Domains

If a legitimate site is blocked:

```bash
# Whitelist a domain
docker exec mithril pihole -w example.com

# Whitelist with wildcard
docker exec mithril pihole --white-wild example.com
```

### Updating Blocklists

Blocklists are automatically updated weekly. To force an update:

```bash
docker exec mithril pihole -g
```

## Examples

See the [examples/](examples/) directory for various deployment configurations:

- `docker-compose-cleanbrowsing.yml` - Using CleanBrowsing DNS
- `docker-compose-opendns.yml` - Using OpenDNS FamilyShield
- `docker-compose-host-network.yml` - Host network mode with DHCP
- `docker-compose-custom.yml` - Custom configuration options

## Building from Source

```bash
# Basic build
./build.sh

# Build with specific tag
./build.sh -t mithril:v1.0

# Build with caching enabled
./build.sh use_cache

# Build from specific branches
./build.sh -c master -w master -f master
```

## Upgrading

1. Pull the latest changes:
   ```bash
   git pull
   ```

2. Rebuild the image:
   ```bash
   ./build.sh
   ```

3. Recreate the container:
   ```bash
   docker compose down
   docker compose up -d
   ```

## Troubleshooting

### Check if Mithril is running
```bash
docker compose ps
docker logs mithril
```

### Test DNS resolution
```bash
# Should return 0.0.0.0 or Pi-hole IP for blocked sites
nslookup NSFW_SITE YOUR_MITHRIL_IP

# Should resolve normally for allowed sites
nslookup google.com YOUR_MITHRIL_IP
```

### View blocked queries
Access the web interface dashboard or:
```bash
docker exec mithril pihole -t
```

### Reset admin password
```bash
docker exec mithril pihole setpassword newpassword
```

## Security Considerations

- **Change the default password** - Always set a strong password
- **Restrict web interface access** - Consider firewall rules to limit admin access
- **Monitor bypass attempts** - Check logs for DNS-over-HTTPS or VPN usage
- **Keep updated** - Regularly update blocklists and the container image

## Credits

- [Pi-hole](https://pi-hole.net/) - The original DNS sinkhole project
- [docker-pi-hole](https://github.com/pi-hole/docker-pi-hole) - Official Pi-hole Docker image
- [StevenBlack/hosts](https://github.com/StevenBlack/hosts) - Unified hosts file with extensions
- [OISD](https://oisd.nl/) - Domain blocklists
- All the maintainers of the various blocklists included

## License

This project is licensed under the [European Union Public License (EUPL) v1.2](LICENSE), the same license as the original pi-hole/docker-pi-hole project.

## Disclaimer

Mithril is provided as-is without warranty. No content filtering solution is 100% effective. This tool is meant to complement, not replace, proper supervision and education about internet safety.
