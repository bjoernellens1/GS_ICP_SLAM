# Quick Start Guide for GS-ICP SLAM Docker Setup

This guide helps you get started quickly with the new Docker setup.

## Prerequisites

Choose your container runtime:

### Option A: Docker (Recommended)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### Option B: Podman
```bash
# Install Podman
sudo apt-get install -y podman

# Setup GPU support
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

## Quick Start Options

### 1. Use Pre-built Images (Fastest)

```bash
# Pull and run (note: lowercase repository name)
docker pull ghcr.io/bjoernellens1/gs_icp_slam:latest-runtime
docker run -it --rm --gpus all --runtime=nvidia \
  -v $(pwd)/dataset:/app/dataset \
  -v $(pwd)/experiments:/app/experiments \
  ghcr.io/bjoernellens1/gs_icp_slam:latest-runtime
```

### 2. Build and Run with Docker Compose

```bash
# Clone repository
git clone --recursive https://github.com/bjoernellens1/GS_ICP_SLAM.git
cd GS_ICP_SLAM

# Build (first time, takes ~30 min)
docker compose build

# Run
docker compose up -d
docker compose exec gs-icp-slam bash

# Inside container
cd /app/GS_ICP_SLAM
python gs_icp_slam.py --help
```

### 3. Development with VS Code

```bash
# Open project in VS Code
code GS_ICP_SLAM

# Install "Remote - Containers" extension
# Press Ctrl+Shift+P -> "Dev Containers: Reopen in Container"
# Wait for build (first time)
# Start coding!
```

### 4. Podman Users

```bash
# Use helper script
./run-podman.sh build  # First time
./run-podman.sh run    # Interactive shell

# Or with podman-compose
podman-compose up -d
podman-compose exec gs-icp-slam bash
```

## Running the System

### Replica Dataset Example

```bash
# Download dataset (if not already)
bash download_replica.sh

# Run evaluation
python -W ignore gs_icp_slam.py \
  --dataset_path /app/dataset/Replica/office0 \
  --config configs/Replica/caminfo.txt \
  --output_path /app/experiments/results/office0
```

### TUM Dataset Example

```bash
# Download dataset (if not already)
bash download_tum.sh

# Run evaluation
python -W ignore gs_icp_slam.py \
  --dataset_path /app/dataset/TUM/rgbd_dataset_freiburg1_desk \
  --config configs/TUM/rgbd_dataset_freiburg1_desk.txt \
  --output_path /app/experiments/results/freiburg1_desk
```

### With Visualization

```bash
# Using rerun.io viewer
python -W ignore gs_icp_slam.py --rerun_viewer

# Using SIBR viewer (requires two terminals)
# Terminal 1:
python -W ignore gs_icp_slam.py --dataset_path /app/dataset/Replica/office0 --verbose

# Terminal 2:
cd SIBR_viewers
./install/bin/SIBR_remoteGaussian_app --rendering-size 1280 720
```

## Verify GPU Access

```bash
# Check NVIDIA driver
nvidia-smi

# Inside container
docker run --rm --gpus all --runtime=nvidia \
  ghcr.io/bjoernellens1/gs_icp_slam:latest-runtime \
  nvidia-smi

# Check PyTorch CUDA
docker run --rm --gpus all --runtime=nvidia \
  ghcr.io/bjoernellens1/gs_icp_slam:latest-runtime \
  python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0)}')"
```

## Common Issues

### GPU not detected
```bash
# Check Docker daemon config
cat /etc/docker/daemon.json
# Should contain nvidia runtime

# Restart Docker
sudo systemctl restart docker
```

### X11 forwarding issues
```bash
# Allow X11 connections
xhost +local:docker

# Or for Podman
xhost +local:
```

### Build fails
```bash
# Clear cache and rebuild
docker builder prune -a
docker compose build --no-cache
```

## What's Next?

- Check [DOCKER_SETUP_SUMMARY.md](DOCKER_SETUP_SUMMARY.md) for implementation details
- See [README.MD](README.MD) for dataset setup and configuration

## Getting Help

- GitHub Issues: https://github.com/bjoernellens1/GS_ICP_SLAM/issues
- Validate setup: `./validate-docker-setup.sh`

## Summary of Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build definition |
| `docker-compose.yml` | Production/evaluation setup |
| `docker-compose.dev.yml` | Development setup |
| `.devcontainer/devcontainer.json` | VS Code integration |
| `run-podman.sh` | Podman helper script |
| `validate-docker-setup.sh` | Setup validation |

Happy SLAMing! 🚀
