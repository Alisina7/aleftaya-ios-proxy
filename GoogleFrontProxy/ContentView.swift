import SwiftUI
import Darwin

// ۱. ساخت یک کلاس مدیریت (ViewModel) برای هندل کردن لاگ‌های سنگین و پیوسته
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
        
        // ساخت لوله‌های ارتباطی (Pipes) برای گرفتن خروجی Rust
        var outPipe: [Int32] = [0, 0]
        Darwin.pipe(&outPipe)
        
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        
        // هدایت خروجی استاندارد و ارورها به داخل لوله
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
            
            // بستن سرِ نوشتن لوله در برنامه اصلی
            close(outPipe[1])
            
            // شروع خواندن زنده لاگ‌ها از هسته Rust
            logHandle = FileHandle(fileDescriptor: outPipe[0])
            logHandle?.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty {
                    // پروسس بسته شده است
                    handle.readabilityHandler = nil
                } else if let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.appendLog(str)
                    }
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
    
    // تابعی برای اضافه کردن لاگ و جلوگیری از پر شدن بیش از حد حافظه (حداکثر ۵۰۰۰ کاراکتر آخر)
    private func appendLog(_ message: String) {
        logs += message.hasSuffix("\n") ? message : message + "\n"
        if logs.count > 5000 {
            logs = String(logs.suffix(4000))
        }
    }
}

// ۲. رابط کاربری (UI)
struct ContentView: View {
    @AppStorage("userScriptID") private var scriptID = ""
    @AppStorage("userAuthKey") private var authKey = ""
    
    // اتصال کلاس مدیریت به رابط کاربری
    @StateObject private var proxyManager = ProxyManager()
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Image(systemName: proxyManager.isRunning ? "shield.checkered" : "shield.xmark.fill")
                        .font(.system(size: 70))
                        .foregroundColor(proxyManager.isRunning ? .green : .red)
                        .padding(.top, 10)
                    
                    Text("AlefTaya Proxy")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
                
                // Status Info
                HStack {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(proxyManager.isRunning ? .green : .red)
                    Text(proxyManager.isRunning ? "Status: Active (PID: \(proxyManager.currentPID))" : "Status: Stopped")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Live Terminal Log View (همراه با اسکرول خودکار)
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        Text(proxyManager.logs)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .id("LOG_BOTTOM") // آیدی برای اسکرول
                    }
                    .frame(height: 300)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1)))
                    .padding(.horizontal)
                    // وقتی لاگ جدید می‌آید، خودکار به پایین اسکرول کن
                    .onChange(of: proxyManager.logs) { _ in
                        withAnimation {
                            scrollProxy.scrollTo("LOG_BOTTOM", anchor: .bottom)
                        }
                    }
                }
                
                // Control Button
                Button(action: {
                    if proxyManager.isRunning {
                        proxyManager.stop()
                    } else {
                        proxyManager.start(scriptID: scriptID, authKey: authKey)
                    }
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

// ۳. صفحه تنظیمات (تغییری نکرده)
struct SettingsView: View {
    @Binding var scriptID: String
    @Binding var authKey: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Google Server Configuration"), footer: Text("Saved securely on device.")) {
                    TextField("Deployment Script ID", text: $scriptID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("Authentication Key", text: $authKey)
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
