#!/usr/bin/env python3
"""
Simple HTTP server to serve DMG files for iframe embedding.
Run with: python3 server.py
"""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os
import json

class DMGHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            # Generate download page
            html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ollama MacOS App Download</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .download-card {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 400px;
        }
        .icon {
            font-size: 64px;
            margin-bottom: 20px;
        }
        h1 {
            margin: 0 0 10px 0;
            color: #333;
        }
        p {
            color: #666;
            margin-bottom: 30px;
        }
        .download-btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 40px;
            font-size: 18px;
            border-radius: 30px;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            text-decoration: none;
            display: inline-block;
        }
        .download-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        .file-info {
            margin-top: 20px;
            font-size: 12px;
            color: #999;
        }
    </style>
</head>
<body>
    <div class="download-card">
        <div class="icon">📦</div>
        <h1>Ollama MacOS App</h1>
        <p>Download the latest version for macOS</p>
        <a href="/download" class="download-btn">Download .dmg</a>
        <div class="file-info">
            Version 1.0.0 • macOS 10.15+
        </div>
    </div>
</body>
</html>
"""
            self.wfile.write(html.encode())
            
        elif self.path == '/download':
            # Check if DMG file exists
            dmg_path = 'OllamaMacOSApp.dmg'
            if os.path.exists(dmg_path):
                self.send_response(200)
                self.send_header('Content-type', 'application/x-apple-diskimage')
                self.send_header('Content-Disposition', 'attachment; filename="OllamaMacOSApp.dmg"')
                self.end_headers()
                
                with open(dmg_path, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                error = {"error": "DMG file not found", "path": dmg_path}
                self.wfile.write(json.dumps(error).encode())
        else:
            super().do_GET()

def run_server(port=8000):
    server_address = ('', port)
    httpd = HTTPServer(server_address, DMGHandler)
    print(f"Server running at http://localhost:{port}")
    print(f"Embed with: <iframe src=\"http://localhost:{port}\" width=\"400\" height=\"300\"></iframe>")
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
