#!/bin/bash

# PocketBase Docker Local Testing Setup Script
# This script sets up a local Docker environment for testing PocketBase

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker is installed"
}

# Check if Docker daemon is running
check_docker_daemon() {
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    print_success "Docker daemon is running"
}

# Create local data directories
setup_data_dirs() {
    print_header "Setting up local data directories"
    
    # Default directory
    DATA_DIR="./data"
    
    # Ask user for custom path
    echo -e "Enter the local data directory path (default: ${BLUE}${DATA_DIR}${NC}):"
    read -r user_input
    
    if [ -n "$user_input" ]; then
        DATA_DIR="$user_input"
    fi
    
    print_info "Creating directories in: ${DATA_DIR}"
    
    # Create directories
    mkdir -p "${DATA_DIR}/pb_data"
    mkdir -p "${DATA_DIR}/pb_public"
    mkdir -p "${DATA_DIR}/pb_hooks"
    mkdir -p "${DATA_DIR}/pb_migrations"
    
    # Set permissions (important for Docker user mapping)
    chmod -R 755 "${DATA_DIR}"
    
    print_success "Created: ${DATA_DIR}/pb_data"
    print_success "Created: ${DATA_DIR}/pb_public"
    print_success "Created: ${DATA_DIR}/pb_hooks"
    print_success "Created: ${DATA_DIR}/pb_migrations"
    
    # Return the data dir for later use
    echo "$DATA_DIR"
}

# Create docker-compose.local.yml
create_local_compose() {
    local data_dir=$1
    
    print_header "Creating docker-compose.local.yml"
    
    # Get absolute path
    abs_data_dir=$(cd "$data_dir" && pwd)
    
    # Ask for port
    echo -e "Enter the port to expose PocketBase on (default: ${BLUE}8090${NC}):"
    read -r port_input
    PORT=${port_input:-8090}
    
    # Create docker-compose.local.yml
    cat > docker-compose.local.yml << EOF
version: '3.8'

services:
  pocketbase:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: pocketbase-local
    restart: unless-stopped
    ports:
      - "${PORT}:8090"
    volumes:
      # Using local data directory for testing
      - ${abs_data_dir}/pb_data:/pb/pb_data
      - ${abs_data_dir}/pb_public:/pb/pb_public
      - ${abs_data_dir}/pb_hooks:/pb/pb_hooks
      - ${abs_data_dir}/pb_migrations:/pb/pb_migrations
    environment:
      - PB_HTTP_ADDR=0.0.0.0:8090
      - PB_DATA_DIR=/pb/pb_data
      - PB_HOOKS_DIR=/pb/pb_hooks
      - PB_MIGRATIONS_DIR=/pb/pb_migrations
      - PB_PUBLIC_DIR=/pb/pb_public
      # Optional: Add encryption key for testing
      # - PB_ENCRYPTION_ENV=test_encryption_key_32_chars
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8090/api/health"]
      interval: 30s
      timeout: 3s
      start_period: 5s
      retries: 3

# Note: Not using named volumes here for easier cleanup during testing
EOF
    
    print_success "Created docker-compose.local.yml"
    print_info "Data directory: ${abs_data_dir}"
    print_info "Port: ${PORT}"
}

# Update .gitignore
update_gitignore() {
    print_header "Updating .gitignore"
    
    # Check if entries already exist
    if grep -q "docker-compose.local.yml" .gitignore 2>/dev/null && \
       grep -q "^data/$" .gitignore 2>/dev/null; then
        print_info ".gitignore already contains necessary entries"
        return
    fi
    
    # Add entries if they don't exist
    echo "" >> .gitignore
    echo "# Local Docker testing" >> .gitignore
    echo "docker-compose.local.yml" >> .gitignore
    echo "data/" >> .gitignore
    
    print_success "Updated .gitignore to ignore local testing files"
}

# Build Docker image
build_image() {
    print_header "Building Docker image"
    
    echo -e "Do you want to build the Docker image now? (${GREEN}y${NC}/${RED}n${NC})"
    read -r build_choice
    
    if [[ "$build_choice" =~ ^[Yy]$ ]]; then
        print_info "Building PocketBase Docker image..."
        docker build -t pocketbase:local .
        print_success "Docker image built successfully"
    else
        print_warning "Skipped Docker image build"
        print_info "You can build it later with: docker build -t pocketbase:local ."
    fi
}

# Start containers
start_containers() {
    print_header "Starting Docker containers"
    
    echo -e "Do you want to start the containers now? (${GREEN}y${NC}/${RED}n${NC})"
    read -r start_choice
    
    if [[ "$start_choice" =~ ^[Yy]$ ]]; then
        print_info "Starting containers with docker-compose..."
        docker-compose -f docker-compose.local.yml up -d
        print_success "Containers started successfully"
        
        # Wait a moment for health check
        print_info "Waiting for PocketBase to be ready..."
        sleep 5
        
        # Get the port from docker-compose.local.yml
        local port=$(grep -oP '- "\K[0-9]+(?=:8090)' docker-compose.local.yml | head -1)
        
        print_success "PocketBase is running!"
        echo ""
        print_info "Access the admin UI at: ${GREEN}http://localhost:${port}/_/${NC}"
        print_info "API endpoint: ${GREEN}http://localhost:${port}/api/${NC}"
        echo ""
        print_info "View logs: ${BLUE}docker-compose -f docker-compose.local.yml logs -f${NC}"
        print_info "Stop containers: ${BLUE}docker-compose -f docker-compose.local.yml down${NC}"
        print_info "Restart containers: ${BLUE}docker-compose -f docker-compose.local.yml restart${NC}"
    else
        print_warning "Skipped starting containers"
        echo ""
        print_info "Start containers later with:"
        echo "  docker-compose -f docker-compose.local.yml up -d"
    fi
}

# Print summary
print_summary() {
    print_header "Setup Complete!"
    
    echo "Your local Docker testing environment is ready!"
    echo ""
    echo -e "${GREEN}Quick Reference:${NC}"
    echo "  • Start:   docker-compose -f docker-compose.local.yml up -d"
    echo "  • Stop:    docker-compose -f docker-compose.local.yml down"
    echo "  • Logs:    docker-compose -f docker-compose.local.yml logs -f"
    echo "  • Rebuild: docker-compose -f docker-compose.local.yml up -d --build"
    echo ""
    echo -e "${YELLOW}Testing the permission fix:${NC}"
    echo "  1. The Docker container runs with the binary in /usr/local/bin/"
    echo "  2. Data is stored in /pb/pb_data (specified with --dir flag)"
    echo "  3. Check logs to verify no permission errors occur"
    echo ""
    echo -e "${BLUE}Data Location:${NC}"
    echo "  Local: ./data/pb_data/"
    echo "  Container: /pb/pb_data/"
    echo ""
}

# Main execution
main() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║         PocketBase Docker Local Testing Setup                 ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    print_info "This script will set up a local Docker environment for testing PocketBase"
    print_info "with properly configured data directories."
    echo ""
    
    # Check prerequisites
    check_docker
    check_docker_daemon
    
    # Setup process
    data_dir=$(setup_data_dirs)
    create_local_compose "$data_dir"
    update_gitignore
    build_image
    start_containers
    print_summary
}

# Run main function
main
