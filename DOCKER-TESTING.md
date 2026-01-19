# Local Docker Testing Guide

This guide explains how to test PocketBase Docker setup locally, including testing the permission fix.

## Quick Start

```bash
./setup-docker.sh
```

Follow the interactive prompts to set up your local testing environment.

## What Gets Created

The setup script creates:

```
.
├── data/                          # Git-ignored local data directory
│   ├── pb_data/                   # Database and uploaded files
│   ├── pb_public/                 # Static files
│   ├── pb_hooks/                  # JavaScript hooks
│   └── pb_migrations/             # Custom migrations
└── docker-compose.local.yml       # Git-ignored local compose file
```

## Manual Testing Steps

### 1. Build the Image

```bash
docker build -t pocketbase:local .
```

### 2. Create Test Directories

```bash
mkdir -p data/{pb_data,pb_public,pb_hooks,pb_migrations}
```

### 3. Run the Container

```bash
docker run -d \
  --name pocketbase-test \
  -p 8090:8090 \
  -v $(pwd)/data/pb_data:/pb/pb_data \
  -v $(pwd)/data/pb_public:/pb/pb_public \
  -v $(pwd)/data/pb_hooks:/pb/pb_hooks \
  -v $(pwd)/data/pb_migrations:/pb/pb_migrations \
  pocketbase:local
```

### 4. Verify No Permission Errors

```bash
# Check logs for permission denied errors
docker logs pocketbase-test

# Should NOT see:
# mkdir /usr/local/bin/pb_data: permission denied

# Should see successful startup:
# Server started at http://0.0.0.0:8090
```

### 5. Test the Application

```bash
# Health check
curl http://localhost:8090/api/health

# Access admin UI
open http://localhost:8090/_/
```

### 6. Verify Data Persistence

```bash
# Check that data is being written
ls -la data/pb_data/

# Should see database files:
# data.db
# logs.db
# etc.
```

## Testing with Docker Compose

### Using the Local Compose File

```bash
# Start
docker-compose -f docker-compose.local.yml up -d

# View logs
docker-compose -f docker-compose.local.yml logs -f

# Stop
docker-compose -f docker-compose.local.yml down
```

### Rebuild After Changes

```bash
docker-compose -f docker-compose.local.yml up -d --build
```

## Cleanup

### Remove Containers Only

```bash
docker-compose -f docker-compose.local.yml down
```

### Remove Everything (Including Data)

```bash
docker-compose -f docker-compose.local.yml down -v
rm -rf data/
rm docker-compose.local.yml
```

## Testing the Permission Fix

The fix addresses the issue where PocketBase tried to create `pb_data` in `/usr/local/bin/` (where the executable is located).

### What to Verify

1. **Container Setup**:
   - Binary is at: `/usr/local/bin/pocketbase`
   - Runs as non-root user (UID 1000)
   - Uses `--dir=/pb/pb_data` flag

2. **Expected Behavior**:
   - No "permission denied" errors in logs
   - Data is created in `/pb/pb_data` (mapped to `./data/pb_data`)
   - Application starts successfully

3. **Test Scenarios**:

   ```bash
   # Scenario 1: Check container user
   docker exec pocketbase-local whoami
   # Expected: pocketbase
   
   # Scenario 2: Check data directory
   docker exec pocketbase-local ls -la /pb/pb_data
   # Expected: data.db and other files
   
   # Scenario 3: Verify no system directory creation attempts
   docker logs pocketbase-local 2>&1 | grep -i "permission denied"
   # Expected: No output (no permission errors)
   ```

## Troubleshooting

### Permission Issues

If you encounter permission issues with local volumes:

```bash
# Fix ownership (container runs as UID 1000)
sudo chown -R 1000:1000 data/
```

### Port Already in Use

```bash
# Use a different port
docker run -p 8091:8090 ...
# or edit docker-compose.local.yml
```

### Container Won't Start

```bash
# Check detailed logs
docker logs pocketbase-local

# Inspect the container
docker inspect pocketbase-local

# Check if directories exist
ls -la data/
```

### Data Not Persisting

Verify volume mounts:

```bash
docker inspect pocketbase-local | grep -A 10 "Mounts"
```

## Development Workflow

1. Make code changes
2. Rebuild image: `docker-compose -f docker-compose.local.yml up -d --build`
3. Test changes
4. Check logs: `docker-compose -f docker-compose.local.yml logs -f`
5. Repeat

## CI/CD Testing

This local setup mirrors the CI environment to catch issues early:

- Same Dockerfile used in production
- Same volume structure
- Same user permissions
- Same port configuration

## Advanced Testing

### Test with Custom Configuration

Edit `docker-compose.local.yml` to test different configurations:

```yaml
environment:
  - PB_HTTP_ADDR=0.0.0.0:8090
  - PB_ENCRYPTION_ENV=test_key_32_characters_long_key
  # Add more environment variables as needed
```

### Test Multi-Platform

```bash
# Build for different architectures
docker buildx build --platform linux/amd64,linux/arm64 -t pocketbase:local .
```

### Test Resource Limits

Add to `docker-compose.local.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
```

## Best Practices

1. **Always clean up** after testing to avoid disk space issues
2. **Use `.gitignore`** entries to avoid committing test data
3. **Test permission scenarios** regularly when changing Docker setup
4. **Document** any issues you encounter
5. **Verify** the fix works before submitting PRs

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Docker logs: `docker logs pocketbase-local`
3. Check the main [README-DOCKER.md](README-DOCKER.md) for more details
4. Open an issue with:
   - Docker version: `docker --version`
   - OS information
   - Full error logs
   - Steps to reproduce
