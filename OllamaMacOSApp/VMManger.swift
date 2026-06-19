import Foundation
import SwiftUI

class VMManager: ObservableObject {
    @Published var isRunning = false
    @Published var vmName = "ubuntu-dev"
    @Published var vmStatus = "Stopped"
    @Published var terminalOutput: [TerminalLine] = []
    @Published var sshConnected = false
    
    private var limaProcess: Process?
    private var sshProcess: Process?
    private var vmConfigPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".lima")
            .appendingPathComponent("\(vmName)")
            .appendingPathComponent("lima.yaml")
            .path
    }
    
    init() {
        checkLimaInstallation()
    }
    
    private func checkLimaInstallation() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/lima")
        task.arguments = ["version"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                addLine("Lima is installed", type: .info)
            } else {
                addLine("Lima not found. Please install: brew install lima", type: .error)
            }
        } catch {
            addLine("Error checking Lima: \(error.localizedDescription)", type: .error)
        }
    }
    
    func createVM() async throws {
        addLine("Creating Ubuntu VM: \(vmName)", type: .info)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/limactl")
        task.arguments = ["start", "--name=\(vmName)", "template://ubuntu"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        
        // Read output asynchronously
        for try await line in pipe.fileHandleForReading.bytes.lines {
            await MainActor.run {
                addLine(line, type: .output)
            }
        }
        
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            await MainActor.run {
                isRunning = true
                vmStatus = "Running"
                addLine("VM created successfully", type: .success)
            }
        } else {
            await MainActor.run {
                addLine("Failed to create VM", type: .error)
            }
        }
    }
    
    func startVM() async throws {
        addLine("Starting VM: \(vmName)", type: .info)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/limactl")
        task.arguments = ["start", vmName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        
        for try await line in pipe.fileHandleForReading.bytes.lines {
            await MainActor.run {
                addLine(line, type: .output)
            }
        }
        
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            await MainActor.run {
                isRunning = true
                vmStatus = "Running"
                addLine("VM started successfully", type: .success)
            }
        } else {
            await MainActor.run {
                addLine("Failed to start VM", type: .error)
            }
        }
    }
    
    func stopVM() async throws {
        addLine("Stopping VM: \(vmName)", type: .info)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/limactl")
        task.arguments = ["stop", vmName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            await MainActor.run {
                isRunning = false
                vmStatus = "Stopped"
                sshConnected = false
                addLine("VM stopped successfully", type: .success)
            }
        }
    }
    
    func executeCommand(_ command: String) async throws -> String {
        guard isRunning else {
            throw VMError.notRunning
        }
        
        addLine("$ \(command)", type: .input)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/limactl")
        task.arguments = ["shell", vmName, command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        try task.run()
        
        var output = ""
        for try await line in outputPipe.fileHandleForReading.bytes.lines {
            output += line + "\n"
            await MainActor.run {
                addLine(line, type: .output)
            }
        }
        
        for try await line in errorPipe.fileHandleForReading.bytes.lines {
            output += line + "\n"
            await MainActor.run {
                addLine(line, type: .error)
            }
        }
        
        task.waitUntilExit()
        
        return output
    }
    
    func startSSH() async throws {
        guard isRunning else {
            throw VMError.notRunning
        }
        
        addLine("Starting SSH session...", type: .info)
        
        sshProcess = Process()
        sshProcess?.executableURL = URL(fileURLWithPath: "/usr/local/bin/limactl")
        sshProcess?.arguments = ["shell", "--workdir", "~", vmName]
        
        let pipe = Pipe()
        sshProcess?.standardOutput = pipe
        sshProcess?.standardError = pipe
        sshProcess?.standardInput = pipe
        
        try sshProcess?.run()
        
        await MainActor.run {
            sshConnected = true
            addLine("SSH session started", type: .success)
        }
    }
    
    func getFileContent(path: String) async throws -> String {
        let result = try await executeCommand("cat \(path)")
        return result
    }
    
    func writeFile(path: String, content: String) async throws {
        let escapedContent = content.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await executeCommand("echo '\(escapedContent)' > \(path)")
    }
    
    func listDirectory(path: String = "~") async throws -> [String] {
        let result = try await executeCommand("ls -la \(path)")
        return result.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    private func addLine(_ text: String, type: TerminalLineType) {
        terminalOutput.append(TerminalLine(text: text, type: type, timestamp: Date()))
    }
    
    func clearTerminal() {
        terminalOutput.removeAll()
    }
}

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let type: TerminalLineType
    let timestamp: Date
}

enum TerminalLineType {
    case input
    case output
    case error
    case info
    case success
}

enum VMError: Error {
    case notRunning
    case commandFailed
    case notInstalled
}
