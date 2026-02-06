#!/bin/bash
# Helper script for running GS-ICP SLAM with Podman
# This script provides an easy way to use Podman with NVIDIA GPU support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="gs-icp-slam:latest"
CONTAINER_NAME="gs-icp-slam-podman"
DATASET_DIR="${DATASET_DIR:-$(pwd)/dataset}"
EXPERIMENTS_DIR="${EXPERIMENTS_DIR:-$(pwd)/experiments}"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Podman is installed
check_podman() {
    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed. Please install Podman first."
        exit 1
    fi
    print_info "Podman version: $(podman --version)"
}

# Check NVIDIA GPU support
check_nvidia() {
    if ! command -v nvidia-smi &> /dev/null; then
        print_warning "nvidia-smi not found. GPU support may not work."
        return 1
    fi
    
    if ! nvidia-smi &> /dev/null; then
        print_warning "NVIDIA driver not loaded properly."
        return 1
    fi
    
    print_info "NVIDIA GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
    return 0
}

# Build the image
build_image() {
    print_info "Building Podman image..."
    podman build -t "$IMAGE_NAME" --target runtime .
    print_info "Image built successfully: $IMAGE_NAME"
}

# Run the container
run_container() {
    local mode="${1:-interactive}"
    
    # Create directories if they don't exist
    mkdir -p "$DATASET_DIR" "$EXPERIMENTS_DIR"
    
    print_info "Starting container: $CONTAINER_NAME"
    print_info "Dataset directory: $DATASET_DIR"
    print_info "Experiments directory: $EXPERIMENTS_DIR"
    
    # Check if container already exists
    if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Container $CONTAINER_NAME already exists. Removing..."
        podman rm -f "$CONTAINER_NAME"
    fi
    
    # Determine GPU device option
    GPU_DEVICE=""
    if check_nvidia; then
        # Check if CDI is available
        if podman info 2>&1 | grep -q "nvidia.com/gpu"; then
            GPU_DEVICE="--device nvidia.com/gpu=all"
            print_info "Using CDI for GPU access"
        else
            print_warning "CDI not configured. Trying legacy GPU support..."
            GPU_DEVICE="--security-opt=label=disable"
        fi
    fi
    
    # Run container
    if [ "$mode" = "interactive" ]; then
        podman run -it --rm \
            --name "$CONTAINER_NAME" \
            $GPU_DEVICE \
            --privileged \
            --network=host \
            --shm-size=12gb \
            --ipc=host \
            -e DISPLAY="${DISPLAY:-:0}" \
            -e NVIDIA_VISIBLE_DEVICES=all \
            -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics \
            -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
            -v "$DATASET_DIR":/app/dataset:rw \
            -v "$EXPERIMENTS_DIR":/app/experiments:rw \
            "$IMAGE_NAME" \
            /bin/bash
    else
        podman run -d \
            --name "$CONTAINER_NAME" \
            $GPU_DEVICE \
            --privileged \
            --network=host \
            --shm-size=12gb \
            --ipc=host \
            -e DISPLAY="${DISPLAY:-:0}" \
            -e NVIDIA_VISIBLE_DEVICES=all \
            -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics \
            -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
            -v "$DATASET_DIR":/app/dataset:rw \
            -v "$EXPERIMENTS_DIR":/app/experiments:rw \
            "$IMAGE_NAME" \
            tail -f /dev/null
        print_info "Container started in background. Use 'podman exec -it $CONTAINER_NAME bash' to enter."
    fi
}

# Execute command in running container
exec_container() {
    if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Container $CONTAINER_NAME is not running."
        exit 1
    fi
    
    podman exec -it "$CONTAINER_NAME" "$@"
}

# Stop the container
stop_container() {
    print_info "Stopping container: $CONTAINER_NAME"
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
    print_info "Container stopped and removed."
}

# Setup CDI for NVIDIA GPU
setup_cdi() {
    print_info "Setting up CDI for NVIDIA GPU..."
    
    if ! command -v nvidia-ctk &> /dev/null; then
        print_error "nvidia-ctk not found. Please install nvidia-container-toolkit."
        exit 1
    fi
    
    sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
    print_info "CDI configuration generated at /etc/cdi/nvidia.yaml"
    
    # Verify CDI
    if podman info 2>&1 | grep -q "nvidia.com/gpu"; then
        print_info "CDI is properly configured!"
    else
        print_warning "CDI may not be properly configured. Try restarting Podman service."
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
    build           Build the Podman image
    run             Run container in interactive mode (default)
    start           Start container in background
    exec [CMD]      Execute command in running container
    stop            Stop and remove the container
    setup-cdi       Setup NVIDIA GPU support via CDI
    help            Show this help message

Environment Variables:
    DATASET_DIR     Path to dataset directory (default: ./dataset)
    EXPERIMENTS_DIR Path to experiments directory (default: ./experiments)

Examples:
    $0 build
    $0 run
    $0 start
    $0 exec bash
    $0 exec python gs_icp_slam.py --help
    $0 stop

EOF
}

# Main
main() {
    check_podman
    
    case "${1:-run}" in
        build)
            build_image
            ;;
        run)
            run_container interactive
            ;;
        start)
            run_container background
            ;;
        exec)
            shift
            exec_container "$@"
            ;;
        stop)
            stop_container
            ;;
        setup-cdi)
            setup_cdi
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
