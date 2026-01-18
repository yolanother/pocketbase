# PocketBase Docker Deployment Guide

This guide covers deploying PocketBase using Docker and Docker Compose, with special focus on Portainer Stack deployment for NAS systems.

## Table of Contents

- [Quick Start](#quick-start)
- [Docker Deployment](#docker-deployment)
- [Portainer Stack Deployment](#portainer-stack-deployment)
- [Configuration](#configuration)
- [Volume Mounts](#volume-mounts)
- [Environment Variables](#environment-variables)
- [Building the Image](#building-the-image)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Using Docker Compose

1. Clone this repository or download the `docker-compose.yml` file
2. Run the following command:

```bash
docker-compose up -d
```

3. Access PocketBase at `http://localhost:8090/_/`

### Using Docker Run

```bash
docker build -t pocketbase .
docker run -d \
  --name pocketbase \
  -p 8090:8090 \
  -v $(pwd)/pb_data:/pb/pb_data \
  pocketbase serve --http=0.0.0.0:8090
```

## Docker Deployment

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 1.29+ (optional, for compose deployments)

### Build the Docker Image

```bash
docker build -t pocketbase:latest .
```

### Run with Custom Port

```bash
docker run -d \
  --name pocketbase \
  -p 8080:8090 \
  -v /path/to/data:/pb/pb_data \
  pocketbase:latest serve --http=0.0.0.0:8090
```

## Portainer Stack Deployment

Portainer makes it easy to deploy PocketBase on your NAS or server with a web interface.

### Step-by-Step Guide

1. **Access Portainer**: Navigate to your Portainer dashboard

2. **Create a New Stack**:
   - Go to **Stacks** → **Add Stack**
   - Enter a name (e.g., `pocketbase`)

3. **Choose Deployment Method**:

   #### Option A: Web Editor (Recommended for beginners)
   - Select "Web editor"
   - Copy the contents of `docker-compose.portainer.yml`
   - Paste into the editor

   #### Option B: Git Repository
   - Select "Repository"
   - Repository URL: `https://github.com/yolanother/pocketbase`
   - Repository reference: `main` (or your branch)
   - Compose path: `docker-compose.portainer.yml`

4. **Configure Environment Variables** (Important!):
   
   In the "Environment variables" section, add:
   
   ```
   PB_PORT=8090
   PB_DATA_PATH=/volume1/docker/pocketbase/data
   PB_PUBLIC_PATH=/volume1/docker/pocketbase/public
   PB_HOOKS_PATH=/volume1/docker/pocketbase/hooks
   PB_MIGRATIONS_PATH=/volume1/docker/pocketbase/migrations
   PB_ENCRYPTION_ENV=your_secure_encryption_key
   TZ=America/New_York
   ```
   
   **Note**: Adjust paths according to your NAS structure. Common patterns:
   - Synology: `/volume1/docker/pocketbase/...`
   - QNAP: `/share/Container/pocketbase/...`
   - UnRAID: `/mnt/user/appdata/pocketbase/...`

5. **Deploy the Stack**: Click "Deploy the stack"

6. **Verify Deployment**:
   - Check the container logs in Portainer
   - Access PocketBase at `http://your-nas-ip:8090/_/`

### NAS-Specific Considerations

#### Synology NAS

- **Path Example**: `/volume1/docker/pocketbase`
- **Permissions**: Ensure the Docker user has read/write access
- **Firewall**: Add firewall rule for port 8090 in Control Panel → Security → Firewall

#### QNAP NAS

- **Path Example**: `/share/Container/pocketbase`
- **Container Station**: Can also use Container Station GUI
- **Permissions**: Check shared folder permissions

#### UnRAID

- **Path Example**: `/mnt/user/appdata/pocketbase`
- **Community Applications**: Consider adding to CA templates
- **Array**: Keep data on the array, not cache-only

## Configuration

### Volume Mounts

The following directories should be mounted for persistent storage:

| Container Path | Purpose | Required |
|---------------|---------|----------|
| `/pb/pb_data` | Database and uploaded files | **Yes** |
| `/pb/pb_public` | Static files to serve | No |
| `/pb/pb_hooks` | JavaScript hooks | No |
| `/pb/pb_migrations` | Custom migrations | No |

**Important**: The `/pb/pb_data` directory MUST be persistent storage, especially for production use.

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PB_HTTP_ADDR` | HTTP server listen address | `0.0.0.0:8090` |
| `PB_DATA_DIR` | Data directory path | `/pb/pb_data` |
| `PB_HOOKS_DIR` | Hooks directory path | `/pb/pb_hooks` |
| `PB_MIGRATIONS_DIR` | Migrations directory path | `/pb/pb_migrations` |
| `PB_PUBLIC_DIR` | Public files directory path | `/pb/pb_public` |
| `PB_ENCRYPTION_ENV` | Encryption key for sensitive data | (empty) |
| `TZ` | Timezone | `UTC` |

### Port Configuration

By default, PocketBase listens on port `8090`. To change this:

**Docker Compose**:
```yaml
ports:
  - "8080:8090"  # Expose on host port 8080
```

**Docker Run**:
```bash
docker run -p 8080:8090 ...  # Expose on host port 8080
```

**Portainer Environment Variable**:
```
PB_PORT=8080
```

## Building the Image

### Standard Build

```bash
docker build -t pocketbase:latest .
```

### Build with Custom Tag

```bash
docker build -t myregistry/pocketbase:v1.0.0 .
```

### Multi-Platform Build (ARM64, AMD64)

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t pocketbase:latest .
```

## Advanced Usage

### Using with Reverse Proxy

If you're using a reverse proxy (Nginx, Traefik, Caddy), configure it to forward to the PocketBase container:

**Nginx Example**:
```nginx
location / {
    proxy_pass http://pocketbase:8090;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Traefik Labels** (add to docker-compose):
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.pocketbase.rule=Host(`pocketbase.yourdomain.com`)"
  - "traefik.http.services.pocketbase.loadbalancer.server.port=8090"
```

### Resource Limits

To limit resource usage, add to docker-compose.yml:

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 128M
```

### Backup and Restore

#### Backup
```bash
# Backup pb_data directory
docker exec pocketbase tar -czf /pb/backup.tar.gz -C /pb pb_data

# Copy backup to host
docker cp pocketbase:/pb/backup.tar.gz ./backup.tar.gz
```

#### Restore
```bash
# Stop container
docker-compose down

# Restore data
tar -xzf backup.tar.gz -C ./pb_data

# Start container
docker-compose up -d
```

## Troubleshooting

### Container Won't Start

1. **Check logs**:
   ```bash
   docker logs pocketbase
   ```

2. **Verify volumes exist**:
   ```bash
   docker volume ls
   ls -la ./pb_data
   ```

3. **Check permissions**:
   ```bash
   # Container runs as user 1000:1000
   sudo chown -R 1000:1000 ./pb_data
   ```

### Cannot Access Admin UI

1. **Verify container is running**:
   ```bash
   docker ps | grep pocketbase
   ```

2. **Check port binding**:
   ```bash
   docker port pocketbase
   ```

3. **Test connectivity**:
   ```bash
   curl http://localhost:8090/api/health
   ```

### Permission Denied Errors

The container runs as user `pocketbase` (UID 1000, GID 1000). Ensure mounted volumes have correct permissions:

```bash
sudo chown -R 1000:1000 /path/to/pb_data
sudo chmod -R 755 /path/to/pb_data
```

### Data Not Persisting

Ensure you're using volume mounts or bind mounts correctly:

```yaml
volumes:
  - /absolute/path/to/data:/pb/pb_data  # Bind mount
  # OR
  - pb_data:/pb/pb_data  # Named volume
```

### High Memory Usage

PocketBase is memory-efficient, but if you see high usage:

1. Set resource limits (see [Resource Limits](#resource-limits))
2. Check for large file uploads
3. Monitor database size in `/pb/pb_data`

## Security Best Practices

1. **Use Encryption**: Always set `PB_ENCRYPTION_ENV` in production
2. **Firewall**: Restrict port access to trusted networks
3. **Updates**: Regularly update the PocketBase image
4. **Backups**: Implement automated backup strategy
5. **Reverse Proxy**: Use HTTPS with a reverse proxy (Let's Encrypt)
6. **Strong Passwords**: Use strong admin passwords
7. **Non-root User**: The container already runs as non-root (UID 1000)

## Support

- **PocketBase Documentation**: https://pocketbase.io/docs/
- **GitHub Issues**: https://github.com/pocketbase/pocketbase/issues
- **Discord Community**: https://discord.gg/pocketbase

## License

PocketBase is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for details.
