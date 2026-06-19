from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import requests
import subprocess
import os
import time

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'localhost:11434')

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        response = requests.get(f'http://{OLLAMA_HOST}/api/tags', timeout=2)
        if response.status_code == 200:
            return jsonify({'status': 'healthy', 'ollama': 'running'})
        else:
            return jsonify({'status': 'unhealthy', 'ollama': 'error'}), 500
    except:
        return jsonify({'status': 'unhealthy', 'ollama': 'not_running'}), 500

@app.route('/embed')
def embed():
    """Iframe embed page"""
    return render_template_string('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ollama Docker Embed</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
        }
        .card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        h1 { color: #333; margin-bottom: 15px; font-size: 1.5em; }
        .status {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: bold;
            margin-bottom: 15px;
        }
        .status.healthy { background: #4CAF50; color: white; }
        .status.unhealthy { background: #f44336; color: white; }
        select, textarea, button {
            width: 100%;
            padding: 12px;
            margin: 10px 0;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 14px;
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
            min-height: 80px;
            white-space: pre-wrap;
            margin-top: 10px;
            font-size: 13px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="card">
            <h1>🤖 Ollama Docker</h1>
            <div id="status" class="status">Checking...</div>
            <select id="model">
                <option value="llama3.2">Llama 3.2</option>
                <option value="mistral">Mistral 7B</option>
            </select>
            <textarea id="prompt" placeholder="Enter your prompt..." rows="3"></textarea>
            <button onclick="generate()">Generate</button>
            <div id="output" class="output"></div>
        </div>
    </div>
    <script>
        async function checkHealth() {
            try {
                const response = await fetch('/health');
                const data = await response.json();
                const statusEl = document.getElementById('status');
                if (data.status === 'healthy') {
                    statusEl.textContent = '✓ Healthy';
                    statusEl.className = 'status healthy';
                } else {
                    statusEl.textContent = '✗ Unhealthy';
                    statusEl.className = 'status unhealthy';
                }
            } catch (error) {
                document.getElementById('status').textContent = '✗ Error';
                document.getElementById('status').className = 'status unhealthy';
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
        setInterval(checkHealth, 30000);
    </script>
</body>
</html>
    ''')

@app.route('/api/tags')
def list_models():
    """List available models"""
    try:
        response = requests.get(f'http://{OLLAMA_HOST}/api/tags')
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/generate', methods=['POST'])
def generate():
    """Generate text using a model"""
    data = request.json
    model = data.get('model', 'llama3.2')
    prompt = data.get('prompt', '')
    stream = data.get('stream', False)
    
    try:
        response = requests.post(
            f'http://{OLLAMA_HOST}/api/generate',
            json={
                'model': model,
                'prompt': prompt,
                'stream': stream
            }
        )
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/pull', methods=['POST'])
def pull_model():
    """Pull a model from Ollama"""
    data = request.json
    model_name = data.get('name', '')
    
    if not model_name:
        return jsonify({'error': 'Model name required'}), 400
    
    try:
        result = subprocess.run(
            ['ollama', 'pull', model_name],
            capture_output=True,
            text=True,
            timeout=300
        )
        
        if result.returncode == 0:
            return jsonify({'success': True, 'message': f'Model {model_name} pulled successfully'})
        else:
            return jsonify({'error': result.stderr}), 500
    except subprocess.TimeoutExpired:
        return jsonify({'error': 'Pull operation timed out'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/docs')
def api_docs():
    """API documentation for iframe embedding"""
    return jsonify({
        'endpoints': {
            'GET /': 'Main web interface',
            'GET /embed': 'Iframe embed page (compact UI)',
            'GET /health': 'Health check endpoint',
            'GET /api/tags': 'List available models',
            'POST /api/generate': 'Generate text',
            'POST /api/pull': 'Pull a model',
            'GET /api/docs': 'This API documentation'
        },
        'iframe_example': '<iframe src="http://localhost:7860/embed" width="600" height="400" style="border:none; border-radius:10px;"></iframe>',
        'cors': 'Enabled for all origins',
        'ports': {
            'flask_api': 7860,
            'ollama': 11434
        }
    })

if __name__ == '__main__':
    print("Starting Flask API on port 7860")
    print("Iframe embed available at: http://localhost:7860/embed")
    print("API docs available at: http://localhost:7860/api/docs")
    app.run(host='0.0.0.0', port=7860)
