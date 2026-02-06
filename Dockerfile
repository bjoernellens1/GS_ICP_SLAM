# Multi-stage Dockerfile optimized for evaluation
# Supports NVIDIA P100 (sm60) GPU architecture
# Minimized image size through careful layer management

ARG CUDA_VERSION=11.8.0
ARG UBUNTU_VERSION=20.04

# ============================================================================
# Stage 1: Base stage with system dependencies
# ============================================================================
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} as base

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Install system dependencies in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    wget \
    curl \
    ca-certificates \
    python3.9 \
    python3.9-dev \
    python3-pip \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.9 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1 && \
    ln -sf /usr/bin/python3.9 /usr/bin/python

# Upgrade pip
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# ============================================================================
# Stage 2: ROS and PCL dependencies
# ============================================================================
FROM base as ros-builder

# Install ROS Noetic for PCL support (required for fast_gicp)
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ros-noetic-pcl-ros \
    ros-noetic-eigen-conversions \
    && rm -rf /var/lib/apt/lists/*

# Source ROS setup
RUN echo "source /opt/ros/noetic/setup.bash" >> /etc/bash.bashrc

# ============================================================================
# Stage 3: Python dependencies
# ============================================================================
FROM ros-builder as python-deps

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install PyTorch and dependencies
# Using CUDA 11.8 compatible versions
RUN pip install --no-cache-dir \
    torch==2.0.1 \
    torchvision==0.15.2 \
    torchaudio==2.0.2 \
    --index-url https://download.pytorch.org/whl/cu118

# Install other Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# ============================================================================
# Stage 4: Build submodules
# ============================================================================
FROM python-deps as submodule-builder

# Copy only what's needed for submodules
COPY submodules /app/submodules
COPY .gitmodules /app/.gitmodules

WORKDIR /app

# Build and install fast_gicp
RUN cd submodules/fast_gicp && \
    mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    cd .. && \
    python setup.py install

# Build and install diff-gaussian-rasterization
# Specify CUDA architectures including sm60 for P100
RUN cd submodules/diff-gaussian-rasterization && \
    TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0 7.5 8.0 8.6+PTX" pip install --no-cache-dir .

# Build and install simple-knn
RUN cd submodules/simple-knn && \
    pip install --no-cache-dir .

# ============================================================================
# Stage 5: Final runtime image
# ============================================================================
FROM python-deps as runtime

# Copy built submodules from builder
COPY --from=submodule-builder /usr/local/lib/python3.9/dist-packages /usr/local/lib/python3.9/dist-packages
COPY --from=submodule-builder /root/.local /root/.local

# Copy application code
COPY . /app/GS_ICP_SLAM

WORKDIR /app/GS_ICP_SLAM

# Create necessary directories
RUN mkdir -p /app/dataset /app/experiments/results

# Set environment variables
ENV PYTHONPATH=/app/GS_ICP_SLAM:$PYTHONPATH
ENV PATH=/root/.local/bin:$PATH

# Expose any necessary ports (if using network visualization)
EXPOSE 6009

# Default command
CMD ["/bin/bash"]

# ============================================================================
# Stage 6: Development image with additional tools
# ============================================================================
FROM runtime as development

# Install development dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    nano \
    tmux \
    htop \
    gdb \
    valgrind \
    && rm -rf /var/lib/apt/lists/*

# Install additional Python development tools
RUN pip install --no-cache-dir \
    ipython \
    jupyter \
    pytest \
    black \
    flake8 \
    pylint

# Create a non-root user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    apt-get update && \
    apt-get install -y sudo && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    rm -rf /var/lib/apt/lists/*

# Switch to non-root user
USER $USERNAME

WORKDIR /workspace

CMD ["/bin/bash"]
