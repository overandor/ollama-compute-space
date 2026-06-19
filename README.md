# Ollama Compute Space

A native macOS application that provides a local AI compute environment with intelligent memory management for Ollama models. Features terminal and browser interfaces, per-agent and per-chat RAM allocation, and real-time memory monitoring.

## Features

- **Integrated Ollama Server**: Built-in Ollama server with bundled AI models
- **Terminal Interface**: Command-line interface for AI interaction
- **Browser Interface**: Web-based access to Ollama
- **Memory Management**: 
  - Per-agent memory allocation
  - Per-chat memory allocation
  - Real-time memory monitoring
  - System-wide memory tracking
- **Multiple AI Models**: Support for Llama, Mistral, CodeLlama, Phi, and more
- **Local Processing**: All AI processing happens locally on your Mac
- **macOS Native**: Built with SwiftUI for optimal performance

## Requirements

- macOS 13.0 or later
- 8GB RAM recommended (4GB minimum)
- Apple Silicon (M1/M2/M3) or Intel-based Mac

## Installation

### From DMG

1. Download the DMG file
2. Open the DMG
3. Drag Ollama Compute Space to Applications
4. Launch from Applications

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/ollama-macos-app.git
cd ollama-macos-app

# Build the app
./scripts/build.sh

# The DMG will be created in the build directory
```

### Building with Xcode

1. Open `OllamaMacOSApp.xcodeproj` in Xcode
2. Select "Any Mac" as the target
3. Press Cmd+B to build
4. Run with Cmd+R

## Usage

### Starting the App

1. Launch Ollama Compute Space
2. The Dashboard shows memory status and Ollama server controls
3. Click "Start Server" to begin the Ollama server

### Creating Agents

1. Go to the "Agents" tab
2. Click "New Agent"
3. Enter a name and allocate memory (0.5GB - 16GB)
4. The agent will appear in the agents list

### Creating Chats

1. Select an agent from the list
2. Click "New Chat"
3. Enter a name and allocate memory (0.1GB - 8GB)
4. The chat will be associated with the agent

### Using the Terminal

1. Go to the "Terminal" tab
2. Available commands:
   - `help`: Show available commands
   - `list`: List available models
   - `pull <model>`: Pull a model from Ollama
   - `run <model> <prompt>`: Run a model with a prompt
   - `status`: Show Ollama server status
   - `memory`: Show memory usage
   - `clear`: Clear terminal
   - `exit`: Exit terminal

### Using the Browser

1. Ensure Ollama server is running
2. Go to the "Browser" tab
3. The browser will load the Ollama web interface
4. Interact with models through the web UI

## Memory Management

The app provides several levels of memory management:

### System Memory
- **Total RAM**: Physical memory installed on your Mac
- **Available RAM**: Memory not currently in use
- **App Usage**: Memory used by Ollama Compute Space

### Agent Memory
- Each agent can be allocated 0.5GB - 16GB
- Memory is reserved for the agent's operations
- Current usage is tracked in real-time

### Chat Memory
- Each chat can be allocated 0.1GB - 8GB
- Memory is reserved for the chat's context and operations
- Current usage is tracked in real-time

**Note**: macOS does not support true memory "locking". The app monitors and manages memory allocation, but the OS may still reclaim memory under pressure.

## Supported Models

The app comes with support for several Ollama models:

- **Llama 3.2** (4.7GB): Meta's general-purpose LLM
- **Mistral** (4.1GB): Efficient and capable model
- **CodeLlama** (3.8GB): Programming assistant
- **Phi 3** (2.2GB): Compact and fast model

Additional models can be pulled from Ollama's model registry.

## Architecture

### Core Components

- **MemoryManager**: Handles memory monitoring and allocation
- **OllamaManager**: Manages Ollama server and model operations
- **TerminalView**: Terminal interface implementation
- **BrowserView**: WebKit-based browser interface
- **AgentsView**: Agent and chat management UI
- **SettingsView**: Configuration and preferences

### Memory Management Strategy

The app uses a hierarchical memory allocation system:

1. **System Level**: Monitors total system memory
2. **App Level**: Tracks app memory usage
3. **Agent Level**: Allocates memory to specific agents
4. **Chat Level**: Allocates memory to specific chats within agents

This approach provides fine-grained control similar to Colab's memory allocation, but entirely local.

## Security

- All AI processing happens locally on your Mac
- No data is sent to external servers
- App is sandboxed with appropriate entitlements
- Network access is restricted to local Ollama server

## Troubleshooting

### Server Won't Start

- Ensure Ollama binary is installed or bundled
- Check that port 11434 is not in use
- Review logs in the Dashboard

### Memory Warnings

- Reduce agent/chat memory allocations
- Close unused agents and chats
- Check system memory usage in Activity Monitor

### Models Not Loading

- Ensure server is running
- Check network connectivity for model downloads
- Verify sufficient disk space for models

## Development

### Project Structure

```
ollama-macos-app/
├── OllamaMacOSApp/           # Main app source
│   ├── OllamaMacOSAppApp.swift
│   ├── ContentView.swift
│   ├── MemoryManager.swift
│   ├── OllamaManager.swift
│   ├── TerminalView.swift
│   ├── BrowserView.swift
│   ├── AgentsView.swift
│   ├── SettingsView.swift
│   ├── Info.plist
│   └── OllamaMacOSApp.entitlements
├── OllamaMacOSApp.xcodeproj/ # Xcode project
├── scripts/                  # Build scripts
│   ├── build.sh
│   └── ExportOptions.plist
├── AppStoreMetadata/         # App Store metadata
│   ├── metadata.json
│   └── description.txt
└── README.md
```

### Building for Distribution

```bash
# Build release version
./scripts/build.sh

# The DMG will be created at build/OllamaComputeSpace.dmg
```

### App Store Submission

1. Update bundle identifier in Info.plist
2. Configure signing in Xcode
3. Update ExportOptions.plist with your team ID
4. Build and archive
5. Upload to App Store Connect
6. Use metadata from AppStoreMetadata/ directory

## License

Proprietary. All rights reserved.

## Support

For issues and questions, please visit: https://github.com/yourusername/ollama-macos-app

## Acknowledgments

- Ollama: https://ollama.ai
- Apple SwiftUI Framework
- WebKit for browser integration
