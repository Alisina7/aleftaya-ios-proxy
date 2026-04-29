# 🛡️ aleftaya GoogleFrontProxy (iOS)

[![iOS Version](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)](https://apple.com/ios)
[![TrollStore](https://img.shields.io/badge/Sideload-TrollStore-success.svg)](https://github.com/opa334/TrollStore)
[![Core](https://img.shields.io/badge/Core-Rust-orange.svg)](https://www.rust-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)](#)

**A high-performance, TrollStore-native iOS client for MasterHttpRelayVPN, utilizing a memory-safe Rust core for domain fronting via Google infrastructure.**

>  **توسعه‌دهنده:** [aleftaya](https://github.com/alisina7) | ابزاری برای دسترسی آزاد به اینترنت با دور زدن محدودیت‌های شبکه از طریق سرورهای گوگل.


## 📖 Overview | معرفی
GoogleFrontProxy is an iOS application designed to run seamlessly in the background using **TrollStore** privileges. By leveraging a highly efficient Rust binary and Apple's `posix_spawn`, it bypasses the strict 15MB memory limits of standard iOS Network Extensions. 

It works by masking your internet traffic as standard `www.google.com` requests (Domain Fronting). The traffic is securely forwarded to a free **Google Apps Script (Code.gs)** deployment, which fetches the actual target website and returns it to your device.

## ✨ Key Features | ویژگی‌های کلیدی
* 🚀 **Zero Memory Crashes:** Built on a Rust core, entirely avoiding iOS `NEPacketTunnelProvider` memory constraints.
* 📱 **TrollStore Native:** Runs without needing an Apple Developer Account.
* 🎭 **Domain Fronting:** Bypasses deep packet inspection (DPI) by looking like legitimate Google traffic.
* ☁️ **Serverless Architecture:** No VPS required. Operates purely on free Google accounts.
* 🔋 **Battery Efficient:** Background execution optimized for older devices (e.g., iPhone 7 running iOS 15).

---

## 🏗 System Architecture | معماری سیستم

```text
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐     ┌─────────────┐
│  aleftaya    │     │    Rust Core     │     │ Google Edge  │     │ Code.gs     │
│  iOS App     │────►│  (Local Proxy)   │────►│ (SNI Masked) │────►│ Relay       │──► Internet
│ (SwiftUI)    │     │ 127.0.0.1:8085   │     │  Port 443    │     │ Serverless  │
└──────────────┘     └──────────────────┘     └──────────────┘     └─────────────┘
⚙️ Installation & Usage | نصب و راه‌اندازی
1. Apps Script Setup (Server-side)
Go to Google Apps Script.

Create a new project and paste the Code.gs script from the original MasterHttpRelay project.

Change AUTH_KEY to a strong, secret password.

Deploy as Web App (Execute as: Me, Access: Anyone).

Copy your Deployment ID.

2. App Installation (Client-side)
Go to the Releases page or the Actions tab of this repository.

Download the latest compiled aleftaya_proxy.ipa file.

Open TrollStore on your iPhone and install the IPA file.

3. Configuration
Open the aleftaya Proxy app.

Enter your Deployment ID and Auth Key.

Tap Start Proxy.

Configure your iPhone's Wi-Fi proxy settings to point to 127.0.0.1 port 8085.

(Note: Ensure you have installed and trusted the generated CA Certificate for HTTPS MITM interception as per the original project instructions).

🛠 Build it Yourself (CI/CD)
This project is configured with GitHub Actions. You do not need a Mac to compile the IPA.

Fork this repository.

Go to the Actions tab.

Run the Build aleftaya IPA workflow.

Download the output artifact directly to your phone.

🤝 Credits & Acknowledgments | تقدیر و تشکر
This iOS application is a UI wrapper and system integrator. The true magic of the networking logic belongs to the incredible developers of the original tools:

🥇 MasterHttpRelayVPN: The brilliant original concept, Python implementation, and Code.gs relay script by @abolix and the masterking32 team.

🦀 MasterHttpRelayVPN-RUST: The ultra-fast, memory-safe Rust rewrite by @therealaleph, which serves as the core engine for this iOS app.

🍏 aleftaya: iOS System Architecture, SwiftUI integration, and TrollStore deployment strategy.

⚠️ Disclaimer
This tool is provided for educational, testing, and research purposes only. The developers (aleftaya, abolix, therealaleph) are not responsible for any direct or indirect damages resulting from the use of this software. You are solely responsible for compliance with Google's Terms of Service and your local laws.
