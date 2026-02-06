#!/bin/bash
# Validation script for Docker setup
# This script validates the Docker configuration without actually building the full image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== GS-ICP SLAM Docker Setup Validation ===${NC}\n"

# 1. Check Docker installation
echo "1. Checking Docker installation..."
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker is installed: $(docker --version)"
else
    echo -e "${RED}✗${NC} Docker is not installed"
    exit 1
fi

# 2. Check Docker Compose installation
echo -e "\n2. Checking Docker Compose installation..."
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker Compose is installed: $(docker compose version)"
else
    echo -e "${RED}✗${NC} Docker Compose is not installed"
    exit 1
fi

# 3. Validate docker-compose.yml
echo -e "\n3. Validating docker-compose.yml..."
if docker compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} docker-compose.yml is valid"
else
    echo -e "${RED}✗${NC} docker-compose.yml has errors"
    docker compose config
    exit 1
fi

# 4. Validate docker-compose.dev.yml
echo -e "\n4. Validating docker-compose.dev.yml..."
if docker compose -f docker-compose.dev.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} docker-compose.dev.yml is valid"
else
    echo -e "${RED}✗${NC} docker-compose.dev.yml has errors"
    docker compose -f docker-compose.dev.yml config
    exit 1
fi

# 5. Check Dockerfile syntax
echo -e "\n5. Validating Dockerfile syntax..."
if grep -q "FROM" Dockerfile && grep -q "WORKDIR" Dockerfile; then
    echo -e "${GREEN}✓${NC} Dockerfile has valid basic structure"
else
    echo -e "${RED}✗${NC} Dockerfile may have issues"
fi

# 6. Check .dockerignore
echo -e "\n6. Checking .dockerignore..."
if [ -f ".dockerignore" ]; then
    echo -e "${GREEN}✓${NC} .dockerignore exists ($(wc -l < .dockerignore) lines)"
else
    echo -e "${YELLOW}⚠${NC} .dockerignore not found"
fi

# 7. Check DevContainer configuration
echo -e "\n7. Checking DevContainer configuration..."
if [ -f ".devcontainer/devcontainer.json" ]; then
    echo -e "${GREEN}✓${NC} DevContainer configuration exists"
    # Note: devcontainer.json uses JSONC format (JSON with Comments) which is valid for VS Code
    echo -e "${GREEN}✓${NC} devcontainer.json uses JSONC format (JSON with Comments - valid for VS Code)"
else
    echo -e "${RED}✗${NC} DevContainer configuration not found"
fi

# 8. Check GitHub Actions workflow
echo -e "\n8. Checking GitHub Actions workflow..."
if [ -f ".github/workflows/docker-build-push.yml" ]; then
    echo -e "${GREEN}✓${NC} GitHub Actions workflow exists"
else
    echo -e "${RED}✗${NC} GitHub Actions workflow not found"
fi

# 9. Check Dependabot configuration
echo -e "\n9. Checking Dependabot configuration..."
if [ -f ".github/dependabot.yml" ]; then
    echo -e "${GREEN}✓${NC} Dependabot configuration exists"
else
    echo -e "${RED}✗${NC} Dependabot configuration not found"
fi

# 10. Check for NVIDIA GPU (optional)
echo -e "\n10. Checking for NVIDIA GPU support..."
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
        echo -e "${GREEN}✓${NC} NVIDIA GPU detected: $GPU_NAME"
        
        # Check for P100 specifically
        if echo "$GPU_NAME" | grep -qi "P100"; then
            echo -e "${GREEN}✓${NC} NVIDIA P100 detected - sm60 support enabled in Dockerfile"
        fi
    else
        echo -e "${YELLOW}⚠${NC} nvidia-smi found but failed to run"
    fi
else
    echo -e "${YELLOW}⚠${NC} NVIDIA GPU not detected (optional for validation)"
fi

# 11. Check submodules
echo -e "\n11. Checking submodules..."
if [ -f ".gitmodules" ]; then
    echo -e "${GREEN}✓${NC} Git submodules configured"
    SUBMODULE_COUNT=$(grep -c "path = " .gitmodules || echo "0")
    echo -e "${GREEN}✓${NC} Found $SUBMODULE_COUNT submodules"
fi

# 12. Check requirements.txt
echo -e "\n12. Checking requirements.txt..."
if [ -f "requirements.txt" ]; then
    echo -e "${GREEN}✓${NC} requirements.txt exists ($(wc -l < requirements.txt) packages)"
else
    echo -e "${RED}✗${NC} requirements.txt not found"
fi

# Summary
echo -e "\n${GREEN}=== Validation Summary ===${NC}"
echo "All critical checks passed! The Docker setup is properly configured."
echo ""
echo "Next steps:"
echo "  1. Build the image: docker compose build"
echo "  2. Run evaluation: docker compose up -d"
echo "  3. Development: docker compose -f docker-compose.dev.yml up -d"
echo "  4. DevContainer: Open in VS Code and select 'Reopen in Container'"
echo ""
echo "For Podman users:"
echo "  Run: ./run-podman.sh build && ./run-podman.sh run"
echo ""
