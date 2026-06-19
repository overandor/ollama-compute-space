FROM ollama/ollama:latest

# Install Python and Flask for API
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install flask flask-cors requests

# Set up working directory
WORKDIR /app

# Copy API files
COPY docker-dmg/app.py .
COPY docker-dmg/templates/ ./templates/

# Expose ports
EXPOSE 7860 11434

# Environment variables
ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_MODELS=/models

# Create models directory
RUN mkdir -p /models

# Start script
COPY docker-dmg/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
