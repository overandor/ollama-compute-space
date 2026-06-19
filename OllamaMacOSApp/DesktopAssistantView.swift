import SwiftUI
import AppKit

struct DesktopAssistantView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @State private var isExpanded = false
    @State private var userInput = ""
    @State private var assistantResponse = ""
    @State private var isThinking = false
    @State private var selectedModel: OllamaModel?
    @State private var isVisible = true
    @State private var assistantPosition: CGPoint = CGPoint(x: 100, y: 100)
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Assistant Avatar - Always visible
                ZStack {
                    Circle()
                        .fill(isThinking ? Color.orange : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)
                    
                    // Animated eyes when thinking
                    if isThinking {
                        HStack(spacing: 20) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 15, height: 15)
                                .opacity(0.8)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 15, height: 15)
                                .opacity(0.8)
                        }
                        .offset(y: -5)
                    } else {
                        // Friendly face
                        VStack(spacing: 4) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 12)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 12)
                            }
                            .offset(y: -8)
                            
                            Path { path in
                                path.move(to: CGPoint(x: -15, y: 5))
                                path.addQuadCurve(to: CGPoint(x: 15, y: 5), control: CGPoint(x: 0, y: 15))
                            }
                            .stroke(Color.white, lineWidth: 3)
                            .fill(Color.white)
                        }
                    }
                }
                .onTapGesture(count: 2) {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            assistantPosition = CGPoint(
                                x: assistantPosition.x + value.translation.width,
                                y: assistantPosition.y + value.translation.height
                            )
                        }
                )
                
                // Expanded chat interface
                if isExpanded {
                    VStack(spacing: 12) {
                        // Chat history
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                if assistantResponse.isEmpty {
                                    Text("Hi! I'm your AI assistant. Double-click me to chat!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    Text(assistantResponse)
                                        .font(.body)
                                        .padding()
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .frame(height: 200)
                        .frame(width: 300)
                        
                        // Input field
                        HStack {
                            TextField("Ask me anything...", text: $userInput)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    sendMessage()
                                }
                            
                            Button("Send") {
                                sendMessage()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(userInput.isEmpty || isThinking)
                        }
                        
                        // Model selector
                        Picker("Model", selection: $selectedModel) {
                            ForEach(ollamaManager.models) { model in
                                Text(model.name).tag(model as OllamaModel?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 300)
                        
                        // Close button
                        Button("Hide") {
                            withAnimation {
                                isExpanded = false
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                }
            }
            .position(assistantPosition)
            .frame(width: isExpanded ? 340 : 100, height: isExpanded ? 350 : 100)
        }
    }
    
    private func sendMessage() {
        guard !userInput.isEmpty else { return }
        guard let model = selectedModel ?? ollamaManager.models.first else { return }
        
        let prompt = userInput
        userInput = ""
        isThinking = true
        
        Task {
            do {
                let response = try await ollamaManager.generateResponse(prompt: prompt, model: model)
                
                await MainActor.run {
                    assistantResponse = response
                    isThinking = false
                }
            } catch {
                await MainActor.run {
                    assistantResponse = "Sorry, I couldn't process that. Error: \(error.localizedDescription)"
                    isThinking = false
                }
            }
        }
    }
}

// Wrapper for assistant window controller
class AssistantWindowControllerWrapper: ObservableObject {
    @Published var controller: AssistantWindowController = AssistantWindowController()
    
    func toggleAssistant() {
        controller.toggleAssistant()
    }
    
    func showAssistant() {
        controller.showAssistant()
    }
    
    func hideAssistant() {
        controller.hideAssistant()
    }
}

// Window controller for floating assistant
class AssistantWindowController: NSWindowController, ObservableObject {
    @Published var isVisible = false
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 100, height: 100),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showAssistant() {
        window?.orderFrontRegardless()
        window?.makeKey()
        isVisible = true
    }
    
    func hideAssistant() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    func toggleAssistant() {
        if window?.isVisible == true {
            hideAssistant()
        } else {
            showAssistant()
        }
    }
    
    func setContent(_ view: some View) {
        let hostingView = NSHostingView(rootView: view)
        window?.contentView = hostingView
    }
}
