 ```
🦄 Unicorn Scan 🦄
         _                                              
```
```
             _                                              
 /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __  
/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _` | '_ \ 
\ \_/ / | | | | (_| (_) | |  | | | |   \__ \ (_| (_| | | | |
 \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|
                                  |_____|# Features
```

- **Fast Scan:** Naabu → Nmap (Go build version)
- **Full Recon:** Naabu → Nmap → HTTPX → Gobuster → Nikto → report generation
- **Color-coded phases:** Each tool has unique colors for readability
- **Saved reports:** Organized folders per target
- **ASCII unicorn branding:** Fun and easy to track phases visually

# Quick Start

### 1️⃣ Clone Repo
```
git clone https://github.com/AlexKrechmer/unicorn_scan.git

cd unicorn_scan
```
2️⃣ Install System Dependencies
```
sudo apt update

sudo apt install -y git curl wget nmap gobuster nikto golang-go
```
3️⃣ Install Go (if not using apt version)
```
curl -LO https://go.dev/dl/go1.24.6.linux-amd64.tar.gz

sudo rm -rf /usr/local/go

sudo tar -C /usr/local -xzf go1.24.6.linux-amd64.tar.gz

echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc

source ~/.bashrc
```
go version # should show go1.24.6

4️⃣ Install Naabu & HTTPX
```
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

go install github.com/projectdiscovery/httpx/cmd/httpx@latest
```
5️⃣ Make Script Executable
```
chmod +x unicorn_scan.sh
```
⚡ Full Recon (-full)

Runs Naabu → Nmap → HTTPX → Gobuster → Nikto → report

sudo ./unicorn_scan.sh example.com -full

Output:

Colorful ASCII unicorn

Naabu port scan

Nmap scan on discovered ports

HTTPX probe (green)

Gobuster scan (orange)

Nikto scan (red)

Full report saved in unicorn_report_<target>_<timestamp>/report.txt

⚠️ Gobuster & Nikto will be skipped if not installed or if no HTTP services are found.
Usage Options

🐴 Fast Scan
Quick port scan + Nmap on discovered ports. Minimal output, no HTTP or directory scans.

./unicorn_scan.sh example.com

Output:

Discovered ports

Nmap scan (purple)

Wordlists
Default Gobuster wordlists are included in wordlists/:

small.txt

quickhits.txt

medium.txt

You can customize the Gobuster wordlist path in the script.

Notes

Fast scan: Great for quick reconnaissance

Full scan: Detailed report + all steps automated

Make sure Go binaries (naabu and httpx) are in your PATH for the script to work correctly.

Acknowledgments

For my daughter — this unicorn theme is dedicated to you. 🦄     
