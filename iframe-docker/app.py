from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import subprocess
import os
import time
import threading

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

OLLAMA_HOST = os.getenv('OLLAMA_HOST', '0.0.0.0:11434')

def start_ollama():
    """Start Ollama server in background"""
    try:
        subprocess.Popen(['ollama', 'serve'])
        print("Ollama server started")
    except Exception as e:
        print(f"Failed to start Ollama: {e}")

@app.route('/')
def index():
    """Main iframe-optimized interface"""
    return render_template_string('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ollama Iframe</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            padding: 15px;
            color: #fff;
        }
        .container {
            max-width: 100%;
            margin: 0 auto;
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            padding: 15px;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .header h1 { font-size: 1.2em; }
        .status {
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
        }
        .status.healthy { background: #00d4aa; color: #000; }
        .status.unhealthy { background: #ff6b6b; color: #fff; }
        .chat-container {
            background: rgba(255,255,255,0.05);
            border-radius: 15px;
            padding: 20px;
            backdrop-filter: blur(10px);
        }
        .messages {
            max-height: 300px;
            overflow-y: auto;
            margin-bottom: 15px;
            padding: 10px;
        }
        .message {
            padding: 10px 15px;
            margin: 8px 0;
            border-radius: 10px;
            max-width: 80%;
        }
        .message.user {
            background: #667eea;
            margin-left: auto;
        }
        .message.ai {
            background: rgba(255,255,255,0.1);
        }
        .input-area {
            display: flex;
            gap: 10px;
        }
        select, input, button {
            padding: 12px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
        }
        select { width: 120px; }
        input { flex: 1; }
        button {
            background: #667eea;
            color: white;
            cursor: pointer;
        }
        button:hover { background: #764ba2; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 Ollama Iframe</h1>
            <div id="status" class="status">Checking...</div>
        </div>
        
        <div class="chat-container">
            <div class="messages" id="messages"></div>
            <div class="input-area">
                <select id="model">
                    <option value="llama3.2">Llama 3.2</option>
                    <option value="mistral">Mistral</option>
                    <option value="codellama">Code Llama</option>
                </select>
                <input type="text" id="prompt" placeholder="Type your message..." />
                <button onclick="sendMessage()">Send</button>
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
                    statusEl.textContent = '✓ Online';
                    statusEl.className = 'status healthy';
                } else {
                    statusEl.textContent = '✗ Offline';
                    statusEl.className = 'status unhealthy';
                }
            } catch (error) {
                document.getElementById('status').textContent = '✗ Error';
                document.getElementById('status').className = 'status unhealthy';
            }
        }
        
        function addMessage(role, text) {
            const messagesDiv = document.getElementById('messages');
            const messageDiv = document.createElement('div');
            messageDiv.className = `message ${role}`;
            messageDiv.textContent = text;
            messagesDiv.appendChild(messageDiv);
            messagesDiv.scrollTop = messagesDiv.scrollHeight;
        }
        
        async function sendMessage() {
            const model = document.getElementById('model').value;
            const prompt = document.getElementById('prompt').value;
            
            if (!prompt) return;
            
            addMessage('user', prompt);
            document.getElementById('prompt').value = '';
            
            try {
                const response = await fetch('/api/generate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ model, prompt, stream: false })
                });
                const data = await response.json();
                addMessage('ai', data.response || data.error || 'No response');
            } catch (error) {
                addMessage('ai', 'Error: ' + error.message);
            }
        }
        
        document.getElementById('prompt').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendMessage();
        });
        
        checkHealth();
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
    print("Iframe interface: http://localhost:7860")
    app.run(host='0.0.0.0', port=7860)
