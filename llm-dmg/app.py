from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import subprocess
import os
import threading
import time

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'localhost:11434')
OLLAMA_PATH = os.getenv('OLLAMA_PATH', './ollama')

def start_ollama():
    """Start Ollama server in background"""
    try:
        subprocess.Popen([OLLAMA_PATH, 'serve'])
        print("Ollama server started")
    except Exception as e:
        print(f"Failed to start Ollama: {e}")

@app.route('/')
def index():
    """Main web interface"""
    return render_template_string('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ollama LLM</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
        }
        .header {
            background: white;
            padding: 30px;
            border-radius: 15px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .header h1 { color: #333; margin-bottom: 10px; }
        .header p { color: #666; }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        .card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .card h2 { color: #333; margin-bottom: 15px; font-size: 1.2em; }
        select, textarea, button {
            width: 100%;
            padding: 12px;
            margin: 10px 0;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            cursor: pointer;
        }
        .output {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 8px;
            min-height: 100px;
            white-space: pre-wrap;
            margin-top: 10px;
            font-family: monospace;
        }
        .status {
            display: inline-block;
            padding: 10px 20px;
            border-radius: 20px;
            font-weight: bold;
            margin: 10px 0;
        }
        .status.healthy { background: #4CAF50; color: white; }
        .status.unhealthy { background: #f44336; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 Ollama LLM</h1>
            <p>Local LLM running in your browser</p>
            <div id="status" class="status">Checking...</div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h2>💬 Chat</h2>
                <select id="model">
                    <option value="llama3.2">Llama 3.2</option>
                    <option value="mistral">Mistral 7B</option>
                    <option value="codellama">Code Llama</option>
                </select>
                <textarea id="prompt" placeholder="Enter your prompt..." rows="4"></textarea>
                <button onclick="generate()">Generate</button>
                <div id="output" class="output"></div>
            </div>
            
            <div class="card">
                <h2>📦 Models</h2>
                <button onclick="loadModels()">Refresh Models</button>
                <div id="models" class="output">Loading models...</div>
            </div>
        </div>
    </div>
    
    <script>
        async function checkHealth() {
            try {
                const response = await fetch('/health');
                const data = await response.json();
                const statusEl = document.getElementById('status');
                if (data.status === 'healthy') {
                    statusEl.textContent = '✓ Ollama Running';
                    statusEl.className = 'status healthy';
                } else {
                    statusEl.textContent = '✗ Ollama Not Running';
                    statusEl.className = 'status unhealthy';
                }
            } catch (error) {
                document.getElementById('status').textContent = '✗ Error';
                document.getElementById('status').className = 'status unhealthy';
            }
        }
        
        async function loadModels() {
            try {
                const response = await fetch('/api/tags');
                const data = await response.json();
                const modelsEl = document.getElementById('models');
                
                if (data.models) {
                    modelsEl.textContent = data.models.map(m => m.name).join(', ');
                } else {
                    modelsEl.textContent = 'No models available';
                }
            } catch (error) {
                document.getElementById('models').textContent = 'Error loading models';
            }
        }
        
        async function generate() {
            const model = document.getElementById('model').value;
            const prompt = document.getElementById('prompt').value;
            const outputEl = document.getElementById('output');
            
            if (!prompt) {
                outputEl.textContent = 'Please enter a prompt';
                return;
            }
            
            outputEl.textContent = 'Generating...';
            
            try {
                const response = await fetch('/api/generate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ model, prompt, stream: false })
                });
                const data = await response.json();
                outputEl.textContent = data.response || data.error || 'No response';
            } catch (error) {
                outputEl.textContent = 'Error: ' + error.message;
            }
        }
        
        checkHealth();
        loadModels();
        setInterval(checkHealth, 30000);
    </script>
</body>
</html>
    ''')

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        response = subprocess.run(
            ['curl', '-s', f'http://{OLLAMA_HOST}/api/tags'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if response.returncode == 0:
            return jsonify({'status': 'healthy', 'ollama': 'running'})
        else:
            return jsonify({'status': 'unhealthy', 'ollama': 'error'}), 500
    except:
        return jsonify({'status': 'unhealthy', 'ollama': 'not_running'}), 500

@app.route('/api/tags')
def list_models():
    """List available models"""
    try:
        response = subprocess.run(
            ['curl', '-s', f'http://{OLLAMA_HOST}/api/tags'],
            capture_output=True,
            text=True,
            timeout=5
        )
        return response.stdout
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/generate', methods=['POST'])
def generate():
    """Generate text using a model"""
    data = request.json
    model = data.get('model', 'llama3.2')
    prompt = data.get('prompt', '')
    
    try:
        response = subprocess.run(
            ['curl', '-s', '-X', 'POST', f'http://{OLLAMA_HOST}/api/generate',
             '-H', 'Content-Type: application/json',
             '-d', f'{{"model":"{model}","prompt":"{prompt}","stream":false}}'],
            capture_output=True,
            text=True,
            timeout=60
        )
        return response.stdout
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Start Ollama in background
    threading.Thread(target=start_ollama, daemon=True).start()
    
    # Wait for Ollama to start
    time.sleep(3)
    
    print("Starting Flask API on port 7860")
    print("Web interface: http://localhost:7860")
    app.run(host='127.0.0.1', port=7860)
