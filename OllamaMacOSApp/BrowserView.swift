import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @State private var currentURL: String = "http://localhost:11434"
    @State private var canGoBack = false
    @State private var canGoForward = false
    
    var body: some View {
        VStack(spacing: 0) {
            // URL bar
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)
                
                Button(action: {}) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
                
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                }
                
                TextField("Enter URL", text: $currentURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        // Navigate to URL
                    }
                
                Button("Go") {
                    // Navigate to URL
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Web content
            if ollamaManager.isRunning {
                WebViewRepresentable(url: URL(string: currentURL)!)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Ollama server is not running")
                        .font(.headline)
                    
                    Text("Start the Ollama server from the Dashboard to access the web interface")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Start Server") {
                        Task {
                            try? await ollamaManager.startOllamaServer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
