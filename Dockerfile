# Multi-stage build for PocketBase
# This Dockerfile creates an optimized image suitable for Portainer and NAS deployments

# Stage 1: Build the PocketBase binary
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the PocketBase binary from examples/base (the default distribution)
# CGO_ENABLED=0 for fully static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w" \
    -o pocketbase \
    ./examples/base

# Stage 2: Create the final minimal image
FROM alpine:latest

# Install ca-certificates for HTTPS and other necessities
RUN apk add --no-cache ca-certificates tzdata

# Create a non-root user for security
RUN addgroup -g 1000 pocketbase && \
    adduser -D -u 1000 -G pocketbase pocketbase

# Create directories for data and public files
RUN mkdir -p /pb/pb_data /pb/pb_public /pb/pb_hooks /pb/pb_migrations && \
    chown -R pocketbase:pocketbase /pb

WORKDIR /pb

# Copy the binary from builder
COPY --from=builder /app/pocketbase /usr/local/bin/pocketbase
RUN chmod +x /usr/local/bin/pocketbase

# Switch to non-root user
USER pocketbase

# Expose the default PocketBase port
EXPOSE 8090

# Environment variables with defaults
ENV PB_DATA_DIR=/pb/pb_data
ENV PB_HOOKS_DIR=/pb/pb_hooks
ENV PB_MIGRATIONS_DIR=/pb/pb_migrations
ENV PB_PUBLIC_DIR=/pb/pb_public
ENV PB_HTTP_ADDR=0.0.0.0:8090
ENV PB_ENCRYPTION_ENV=""

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8090/api/health || exit 1

# Volume for persistent data
VOLUME ["/pb/pb_data", "/pb/pb_public", "/pb/pb_hooks", "/pb/pb_migrations"]

# Run PocketBase serve command with configurable options
ENTRYPOINT ["/usr/local/bin/pocketbase"]
CMD ["serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data"]
