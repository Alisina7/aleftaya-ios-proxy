import SwiftUI
import Darwin // الزامی برای استفاده از posix_spawn در iOS

struct ContentView: View {
    @State private var isRunning = false
    @State private var logs = "Welcome to aleftaya Proxy\n"
    @State private var currentPID: pid_t = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isRunning ? "shield.fill" : "shield.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(isRunning ? .green : .gray)
            
            Text("aleftaya Proxy")
                .font(.largeTitle).bold()
            
            VStack(alignment: .leading) {
                Text("Status: \(isRunning ? "Active (PID: \(currentPID))" : "Stopped")")
                    .fontWeight(.bold)
                
                ScrollView {
                    Text(logs)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 250)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
            
            Button(action: toggleProxy) {
                Text(isRunning ? "Stop Proxy" : "Start Proxy")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunning ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    func toggleProxy() {
        if isRunning {
            stopRustCore()
        } else {
            startRustCore()
        }
    }
    
    func startRustCore() {
            // ۱. پیدا کردن مسیر دقیق فایل اجرایی در باندل اپلیکیشن
            guard let binPath = Bundle.main.path(forResource: "MasterHttpRelay-iOS", ofType: nil) else {
                logs += "[!] Error: Binary file 'MasterHttpRelay-iOS' not found in App Bundle.\n"
                return
            }
            
            // ۲. اصلاح دسترسی‌ها (Permissions) - حتماً قبل از تعریف آرگومان‌ها
            // تنظیم دسترسی روی 755 (قابل اجرا)
            let attributes = [FileAttributeKey.posixPermissions: 0o755]
            do {
                try FileManager.default.setAttributes(attributes, ofItemAtPath: binPath)
                logs += "[✓] System permissions set to 755 for binary.\n"
            } catch {
                logs += "[!] Warning: Failed to set attributes via FileManager: \(error.localizedDescription)\n"
                // توجه: این خطا ممکن است به خاطر محدودیت سندباکس در iOS باشد، posix_spawn همچنان ممکن است کار کند.
            }

            // ۳. تنظیم آرگومان‌های خط فرمان (تنظیمات خود را اینجا وارد کنید)
            var args: [UnsafeMutablePointer<CChar>?] = [
                strdup(binPath),
                strdup("--script-id"),
                strdup("YOUR_SCRIPT_ID_HERE"), // آیدی گوگل اسکریپت خود را جایگزین کنید
                strdup("--auth-key"),
                strdup("YOUR_AUTH_KEY_HERE"),  // رمز عبور خود را جایگزین کنید
                nil
            ]
            
            // ۴. اجرای پروسس در پس‌زمینه با posix_spawn
            var pid: pid_t = 0
            let status = posix_spawn(&pid, binPath, nil, nil, &args, nil)
            
            if status == 0 {
                logs += "[✓] aleftaya core started (PID: \(pid))\n"
                logs += "[i] Listening on 127.0.0.1:8085\n"
                currentPID = pid
                isRunning = true
            } else {
                logs += "[!] Failed to start process. System error code: \(status)\n"
                logs += "[i] (Status 1 usually means non-executable binary).\n"
            }
            
            // ۵. آزادسازی حافظه متغیرهای C (بسیار مهم در سوئیفت برای جلوگیری از Memory Leak)
            for arg in args {
                if let a = arg {
                    free(a)
                }
            }
        }
    
    func stopRustCore() {
        if currentPID != 0 {
            // ارسال سیگنال خاتمه به پروسس
            let killStatus = kill(currentPID, SIGKILL)
            if killStatus == 0 {
                logs += "[✓] Process stopped.\n"
            } else {
                logs += "[!] Failed to stop process.\n"
            }
            currentPID = 0
            isRunning = false
        }
    }
}
