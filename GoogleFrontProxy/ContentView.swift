import SwiftUI
import Darwin

struct ContentView: View {
    @State private var isRunning = false
    @State private var logs = "🚀 Welcome to AlefTaya Proxy V1.0\n"
    @State private var currentPID: pid_t = 0
    
    var body: some View {
        VStack(spacing: 25) {
            // Header
            VStack {
                Image(systemName: isRunning ? "shield.checkered" : "shield.xmark.fill")
                    .font(.system(size: 70))
                    .foregroundColor(isRunning ? .green : .red)
                    .padding(.top)
                
                Text("AlefTaya Proxy")
                    .font(.system(size: 28, weight: .black, design: .rounded))
            }
            
            // Status & Logs
            VStack(alignment: .leading) {
                HStack {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(isRunning ? .green : .red)
                    Text(isRunning ? "Status: Active (PID: \(currentPID))" : "Status: Stopped")
                        .font(.headline)
                }
                .padding(.horizontal)
                
                ScrollView {
                    Text(logs)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 280)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1)))
            }
            .padding(.horizontal)
            
            // Control Button
            Button(action: toggleProxy) {
                Text(isRunning ? "STOP PROXY" : "START PROXY")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isRunning ? Color.red : Color.blue)
                    .cornerRadius(15)
                    .shadow(radius: 5)
            }
            .padding(.horizontal)
            
            Text("Tip: For LTE/SIM, use Proxy PAC: 127.0.0.1:8085")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    func toggleProxy() {
        if isRunning { stopRustCore() } else { startRustCore() }
    }
    
    func startRustCore() {
        let fileManager = FileManager.default
        
        // ۱. پیدا کردن مسیر فایل در باندل
        guard let bundlePath = Bundle.main.path(forResource: "MasterHttpRelay-iOS", ofType: nil) else {
            logs += "[!] Error: Binary not found in bundle.\n"
            return
        }
        
        // ۲. کپی کردن به پوشه Documents برای دور زدن محدودیت Read-only باندل
        let docsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let executablePath = docsPath.appendingPathComponent("MasterHttpRelay-iOS").path
        
        do {
            if fileManager.fileExists(atPath: executablePath) {
                try fileManager.removeItem(atPath: executablePath)
            }
            try fileManager.copyItem(atPath: bundlePath, toPath: executablePath)
            
            // ۳. ست کردن دسترسی اجرایی (755) در پوشه Documents (اینجا مجاز است)
            let attributes = [FileAttributeKey.posixPermissions: 0o755]
            try fileManager.setAttributes(attributes, ofItemAtPath: executablePath)
            logs += "[✓] Environment prepared.\n"
        } catch {
            logs += "[!] Setup failed: \(error.localizedDescription)\n"
            return
        }
        
        // ۴. آماده‌سازی آرگومان‌ها
        let scriptID = "YOUR_SCRIPT_ID" // حتما جایگزین کن
        let authKey = "YOUR_KEY"       // حتما جایگزین کن
        
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup(executablePath),
            strdup("--script-id"), strdup(scriptID),
            strdup("--auth-key"), strdup(authKey),
            nil
        ]
        
        // ۵. اجرا با استفاده از posix_spawn
        var pid: pid_t = 0
        let status = posix_spawn(&pid, executablePath, nil, nil, &args, nil)
        
        if status == 0 {
            logs += "[✓] AlefTaya Core Active!\n"
            logs += "[i] Listening on 127.0.0.1:8085\n"
            currentPID = pid
            isRunning = true
        } else {
            logs += "[!] Spawn failed with code: \(status)\n"
        }
        
        for arg in args { free(arg) }
    }
    
    func stopRustCore() {
        if currentPID != 0 {
            kill(currentPID, SIGKILL)
            logs += "[✓] Proxy Stopped.\n"
            currentPID = 0
            isRunning = false
        }
    }
}
