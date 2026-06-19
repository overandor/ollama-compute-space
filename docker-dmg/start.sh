#!/bin/bash

# Start Ollama server in background
ollama serve &

# Wait for Ollama to be ready
echo "Waiting for Ollama server..."
sleep 5

# Start Flask API
echo "Starting Flask API on port 7860..."
python3 app.py
