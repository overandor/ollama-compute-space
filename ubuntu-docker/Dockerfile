FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    python3 \
    python3-pip \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Install Python packages
RUN pip3 install flask flask-cors requests

# Set working directory
WORKDIR /app

# Copy application files
COPY ubuntu-docker/app.py .
COPY ubuntu-docker/templates/ ./templates/

# Create models directory
RUN mkdir -p /models

# Expose ports
EXPOSE 7860 11434

# Environment variables
ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_MODELS=/models

# Copy start script
COPY ubuntu-docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
