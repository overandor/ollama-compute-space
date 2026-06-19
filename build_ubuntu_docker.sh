#!/bin/bash

# Build Ubuntu-based Docker container with Ollama
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_NAME="ollama-ubuntu"
CONTAINER_NAME="ollama-ubuntu-container"

echo "Building Ubuntu-based Docker container with Ollama..."

# Build Docker image
echo "Building Docker image..."
cd "$SCRIPT_DIR"
docker build -f ubuntu-docker/Dockerfile -t $IMAGE_NAME:latest .

# Stop existing container if running
echo "Stopping existing container (if any)..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Run container
echo "Starting container..."
docker run -d \
    --name $CONTAINER_NAME \
    -p 11434:11434 \
    -p 7860:7860 \
    -v ollama-models:/models \
    $IMAGE_NAME:latest

# Wait for container to start
echo "Waiting for container to start..."
sleep 10

# Check container status
echo "Container status:"
docker ps | grep $CONTAINER_NAME

echo ""
echo "✓ Ubuntu container started successfully"
echo ""
echo "Access points:"
echo "  - Web interface: http://localhost:7860"
echo "  - Iframe embed: http://localhost:7860/embed"
echo "  - API docs: http://localhost:7860/api/docs"
echo "  - Health check: http://localhost:7860/health"
echo "  - Ollama API: http://localhost:11434"
echo ""
echo "Container commands:"
echo "  - View logs: docker logs -f $CONTAINER_NAME"
echo "  - Stop container: docker stop $CONTAINER_NAME"
echo "  - Start container: docker start $CONTAINER_NAME"
echo "  - Remove container: docker rm -f $CONTAINER_NAME"
