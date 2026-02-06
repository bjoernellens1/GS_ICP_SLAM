# Docker Setup for GS-ICP SLAM

This directory contains comprehensive Docker configurations for both evaluation and development of GS-ICP SLAM, with support for NVIDIA GPUs (including P100 with sm60 architecture) and compatibility with both Docker and Podman.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Docker Images](#docker-images)
- [Using Docker Compose](#using-docker-compose)
- [Using Podman](#using-podman)
- [Development with DevContainer](#development-with-devcontainer)
- [GPU Support](#gpu-support)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### For Docker

1. **Docker Engine** (20.10 or later)
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```

2. **NVIDIA Container Toolkit**
   ```bash
   # Add NVIDIA package repository
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
     sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   
   # Install nvidia-container-toolkit
   sudo apt-get update
   sudo apt-get install -y nvidia-container-toolkit
   sudo systemctl restart docker
   ```

3. **Docker Compose** (v2.0 or later)
   ```bash
   sudo apt-get install docker-compose-plugin
   ```

### For Podman

1. **Podman** (3.4 or later)
   ```bash
   sudo apt-get update
   sudo apt-get install -y podman
   ```

2. **NVIDIA Container Toolkit** (same as Docker)

3. **Configure CDI for NVIDIA GPU**
   ```bash
   sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
   ```

## Quick Start

### Using Docker Compose (Recommended)

#### For Evaluation
```bash
# Build and run the evaluation container
docker compose up -d

# Enter the container
docker compose exec gs-icp-slam bash

# Inside the container, run evaluation
cd /app/GS_ICP_SLAM
python -W ignore gs_icp_slam.py --dataset_path /app/dataset/Replica/office0
```

#### For Development
```bash
# Build and run the development container
docker compose -f docker-compose.dev.yml up -d

# Enter the container
docker compose -f docker-compose.dev.yml exec gs-icp-slam-dev bash

# Your code is mounted at /workspace
cd /workspace
```

### Using Docker CLI

#### Build the Image
```bash
# Build for evaluation
docker build -t gs-icp-slam:latest --target runtime .

# Build for development
docker build -t gs-icp-slam:dev --target development .
```

#### Run the Container
```bash
# For evaluation
docker run -it --rm \
  --gpus all \
  --runtime=nvidia \
  --privileged \
  --network=host \
  --shm-size=12gb \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v $(pwd)/dataset:/app/dataset:rw \
  -v $(pwd)/experiments:/app/experiments:rw \
  gs-icp-slam:latest \
  /bin/bash

# For development (mounts source code)
docker run -it --rm \
  --gpus all \
  --runtime=nvidia \
  --privileged \
  --network=host \
  --shm-size=12gb \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v $(pwd):/workspace:rw \
  -v $(pwd)/dataset:/app/dataset:rw \
  -v $(pwd)/experiments:/app/experiments:rw \
  gs-icp-slam:dev \
  /bin/bash
```

## Docker Images

The Dockerfile uses multi-stage builds to create optimized images:

### Available Stages

1. **base** - Base system with CUDA and Python
2. **ros-builder** - Adds ROS and PCL dependencies
3. **python-deps** - Installs Python packages
4. **submodule-builder** - Builds C++/CUDA extensions
5. **runtime** - Final evaluation image (optimized for size)
6. **development** - Development image with additional tools

### Image Sizes (Approximate)

- Runtime image: ~8-10 GB
- Development image: ~9-11 GB

### Pre-built Images

Pre-built images are available from GitHub Container Registry:

```bash
# Pull runtime image
docker pull ghcr.io/bjoernellens1/gs_icp_slam:latest-runtime

# Pull development image
docker pull ghcr.io/bjoernellens1/gs_icp_slam:latest-development
```

## Using Docker Compose

### Configuration Options

Both `docker-compose.yml` and `docker-compose.dev.yml` support the following:

#### Environment Variables

Create a `.env` file in the project root:

```bash
# Display for X11 forwarding
DISPLAY=:0

# CUDA architecture (for custom builds)
CUDA_VERSION=11.8.0
UBUNTU_VERSION=20.04
```

#### Volume Mounts

- `./dataset:/app/dataset` - Dataset directory
- `./experiments:/app/experiments` - Output results
- `/tmp/.X11-unix:/tmp/.X11-unix` - X11 socket for GUI

For development, additionally:
- `.:/workspace` - Source code (live reload)

#### Resource Limits

Shared memory is set to 12GB by default. Adjust in docker-compose file:

```yaml
shm_size: '12gb'  # Increase if needed for larger datasets
```

### Common Commands

```bash
# Build images
docker compose build

# Start services in background
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Remove volumes (clean slate)
docker compose down -v
```

## Using Podman

Podman is compatible with Docker Compose files and provides rootless containers.

### Setup Podman Compose

```bash
# Install podman-compose
pip install podman-compose

# Or use podman's compose compatibility
alias docker-compose='podman-compose'
```

### Run with Podman

```bash
# Using podman-compose
podman-compose up -d

# Or directly with podman
podman run -it --rm \
  --security-opt=label=disable \
  --device nvidia.com/gpu=all \
  --privileged \
  --network=host \
  --shm-size=12gb \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v $(pwd)/dataset:/app/dataset:rw \
  -v $(pwd)/experiments:/app/experiments:rw \
  gs-icp-slam:latest \
  /bin/bash
```

### Podman-specific Notes

- Use `--device nvidia.com/gpu=all` instead of `--gpus all`
- Add `--security-opt=label=disable` if SELinux causes issues
- Rootless Podman may need `podman unshare` for some volume operations

## Development with DevContainer

VS Code DevContainers provide a full-featured development environment.

### Setup

1. **Install VS Code Extensions**
   - Remote - Containers
   - Docker

2. **Open in Container**
   ```bash
   # In VS Code
   Command Palette (Ctrl+Shift+P) -> "Dev Containers: Reopen in Container"
   ```

3. **Automatic Configuration**
   - GPU support configured automatically
   - Python environment ready
   - Extensions pre-installed
   - ROS environment sourced

### Features

- IntelliSense for Python and C++
- Integrated debugging
- Git integration
- Pre-configured linting and formatting
- Jupyter notebook support

## GPU Support

### NVIDIA P100 (sm60) Support

The Dockerfile explicitly includes sm60 architecture:

```dockerfile
TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0 7.5 8.0 8.6+PTX"
```

### Verify GPU Access

```bash
# Inside container
nvidia-smi

# Test CUDA with Python
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

### GPU Memory

Monitor GPU memory usage:

```bash
watch -n 1 nvidia-smi
```

## Troubleshooting

### Issue: GPU not accessible

**Solution 1**: Verify NVIDIA drivers and runtime
```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu20.04 nvidia-smi
```

**Solution 2**: Check Docker daemon configuration
```bash
cat /etc/docker/daemon.json
# Should contain:
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
```

### Issue: X11 forwarding not working

**Solution**: Allow X11 connections
```bash
xhost +local:docker
# or for Podman
xhost +local:
```

### Issue: Shared memory errors

**Solution**: Increase `shm_size` in docker-compose file or CLI:
```bash
docker run --shm-size=16gb ...
```

### Issue: Build fails with CUDA errors

**Solution 1**: Clear Docker build cache
```bash
docker builder prune -a
```

**Solution 2**: Specify GPU architecture explicitly
```bash
docker build --build-arg TORCH_CUDA_ARCH_LIST="6.0 7.0 8.0" .
```

### Issue: Podman can't find NVIDIA GPU

**Solution**: Regenerate CDI configuration
```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
podman info --debug 2>&1 | grep -i nvidia
```

## CI/CD Integration

Images are automatically built and pushed to GitHub Container Registry via GitHub Actions.

### Workflow Triggers

- Push to main/master/develop branches
- New version tags (v*)
- Manual workflow dispatch

### Caching Strategy

- Registry cache for faster rebuilds
- Multi-stage builds minimize layer sizes
- BuildKit inline cache enabled

### Using Pre-built Images

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Pull latest image
docker pull ghcr.io/bjoernellens1/gs_icp_slam:latest-runtime
```

## Performance Tips

1. **Use BuildKit**: Enable Docker BuildKit for faster builds
   ```bash
   export DOCKER_BUILDKIT=1
   ```

2. **Multi-core Builds**: Utilize all CPU cores
   ```bash
   docker build --build-arg MAKEFLAGS="-j$(nproc)" .
   ```

3. **Layer Caching**: Order Dockerfile commands from least to most frequently changing

4. **Minimal Base Images**: We use specific Ubuntu 20.04 to minimize size

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Podman Documentation](https://docs.podman.io/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [VS Code DevContainers](https://code.visualstudio.com/docs/devcontainers/containers)

## License

Same as parent project - see LICENSE file in repository root.
