import SwiftUI
import Darwin
import UIKit // برای دسترسی به کلیپ‌بورد

class ProxyManager: ObservableObject {
    @Published var isRunning = false
    @Published var logs = "🚀 Welcome to AlefTaya Proxy V2.0\n[i] Engine ready. Waiting for start...\n"
    @Published var currentPID: pid_t = 0
    private var logHandle: FileHandle?
    
    func start(scriptID: String, authKey: String) {
        if scriptID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           authKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendLog("[!] Error: Script ID and Auth Key are missing. Tap ⚙️ to configure.")
            return
        }
        guard let bundlePath = Bundle.main.path(forResource: "MasterHttpRelay-iOS", ofType: nil) else {
            appendLog("[!] Error: Core binary not found in bundle.")
            return
        }
        
        var outPipe: [Int32] = [0, 0]
        Darwin.pipe(&outPipe)
        
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, outPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, outPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, outPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, outPipe[1])
        
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup(bundlePath),
            strdup("--script-id"), strdup(scriptID),
            strdup("--auth-key"), strdup(authKey),
            nil
        ]
        
        var pid: pid_t = 0
        let status = posix_spawn(&pid, bundlePath, &fileActions, nil, &args, nil)
        posix_spawn_file_actions_destroy(&fileActions)
        
        if status == 0 {
            appendLog("[✓] AlefTaya Core Active! (PID: \(pid))")
            appendLog("[i] Connecting to Google Edge Network...")
            currentPID = pid
            isRunning = true
            close(outPipe[1])
            
            logHandle = FileHandle(fileDescriptor: outPipe[0])
            logHandle?.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else if let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { self?.appendLog(str) }
                }
            }
        } else {
            appendLog("[!] Spawn failed with code: \(status)")
        }
        for arg in args { free(arg) }
    }
    
    func stop() {
        if currentPID != 0 {
            kill(currentPID, SIGKILL)
            appendLog("\n[✓] Connection Terminated.")
            logHandle?.readabilityHandler = nil
            logHandle?.closeFile()
            logHandle = nil
            currentPID = 0
            isRunning = false
        }
    }
    
    private func appendLog(_ message: String) {
        logs += message.hasSuffix("\n") ? message : message + "\n"
        if logs.count > 5000 { logs = String(logs.suffix(4000)) }
    }
}

struct ContentView: View {
    @AppStorage("userScriptID") private var scriptID = ""
    @AppStorage("userAuthKey") private var authKey = ""
    @StateObject private var proxyManager = ProxyManager()
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack {
                    Image(systemName: proxyManager.isRunning ? "shield.checkered" : "shield.xmark.fill")
                        .font(.system(size: 70))
                        .foregroundColor(proxyManager.isRunning ? .green : .red)
                        .padding(.top, 10)
                    Text("AlefTaya Proxy")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
                
                HStack {
                    Circle().frame(width: 10, height: 10)
                        .foregroundColor(proxyManager.isRunning ? .green : .red)
                    Text(proxyManager.isRunning ? "Status: Active (PID: \(proxyManager.currentPID))" : "Status: Stopped")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        Text(proxyManager.logs)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .id("LOG_BOTTOM")
                    }
                    .frame(height: 300)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1)))
                    .padding(.horizontal)
                    .onChange(of: proxyManager.logs) { _ in
                        withAnimation { scrollProxy.scrollTo("LOG_BOTTOM", anchor: .bottom) }
                    }
                }
                
                Button(action: {
                    if proxyManager.isRunning { proxyManager.stop() }
                    else { proxyManager.start(scriptID: scriptID, authKey: authKey) }
                }) {
                    Text(proxyManager.isRunning ? "STOP PROXY" : "START PROXY")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(proxyManager.isRunning ? Color.red : Color.blue)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                }
                .padding(.horizontal)
                
                Text("Proxy: 127.0.0.1:8085")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .navigationBarItems(trailing:
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .disabled(proxyManager.isRunning)
            )
            .sheet(isPresented: $showSettings) {
                SettingsView(scriptID: $scriptID, authKey: $authKey)
            }
        }
    }
}

// ----------------------------------------------------
// صفحه تنظیمات حرفه‌ای با دکمه Paste و Show/Hide
// ----------------------------------------------------
struct SettingsView: View {
    @Binding var scriptID: String
    @Binding var authKey: String
    @Environment(\.presentationMode) var presentationMode
    
    // وضعیت نمایش یا مخفی بودن رمز
    @State private var isAuthKeyVisible = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deployment Script ID"), footer: Text("Paste your Google Apps Script Web App ID here.")) {
                    HStack {
                        // استفاده از TextEditor برای فیلدهای طولانی تا کامل دیده شود
                        TextEditor(text: $scriptID)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 50)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        // دکمه Paste مستقیم از حافظه
                        Button(action: {
                            if let clipboardString = UIPasteboard.general.string {
                                scriptID = clipboardString
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Authentication Key"), footer: Text("Must match the AUTH_KEY in your Code.gs file.")) {
                    HStack {
                        if isAuthKeyVisible {
                            TextField("Secret Key", text: $authKey)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Secret Key", text: $authKey)
                        }
                        
                        // دکمه چشم برای نمایش/مخفی کردن
                        Button(action: { isAuthKeyVisible.toggle() }) {
                            Image(systemName: isAuthKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        // دکمه Paste
                        Button(action: {
                            if let clipboardString = UIPasteboard.general.string {
                                authKey = clipboardString
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                
                Section(header: Text("Local Proxy Details")) {
                    HStack { Text("IP Address"); Spacer(); Text("127.0.0.1").foregroundColor(.gray) }
                    HStack { Text("Port"); Spacer(); Text("8085").foregroundColor(.gray) }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
