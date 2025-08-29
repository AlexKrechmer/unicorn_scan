# Unicorn Scan 🦄

             _                                              
 /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __  
/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _` | '_ \ 
\ \_/ / | | | | (_| (_) | |  | | | |   \__ \ (_| (_| | | | |
 \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|
                                  |_____|


## Features

- **Fast Scan:** Naabu → Nmap (Go build version)
  
- **Full Recon:** Naabu → Nmap → HTTPX → Gobuster → Nikto → report generation
  
- **Color-coded phases:** Each tool has unique colors for readability
  
- **Saved reports:** Organized folders per target
  
- **ASCII unicorn branding:** Fun and easy to track phases visually
  

---

## Quick Start

### 1️⃣ Clone the repo

`git clone https://github.com/AlexKrechmer/unicorn_scan.git` 

`cd unicorn_scan`

### 2️⃣ Install dependencies

**Update & essentials:**

`sudo apt update && sudo apt install -y git curl wget nmap gobuster nikto`

**Install Go (for Naabu & HTTPX):**

`curl -LO https://go.dev/dl/go1.21.2.linux-amd64.tar.gz 
sudo rm -rf /usr/local/go 
sudo tar -C /usr/local -xzf go1.21.2.linux-amd64.tar.gz 
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc 
source ~/.bashrc`

**Install Naabu & HTTPX:**

`go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest 
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest`

> After this, `naabu`, `httpx`, `gobuster`, `nikto`, and `nmap` should be available in your PATH.

---

### 3️⃣ Usage Options

**🐴 Full Recon (.sh)**  
Runs Naabu → Nmap → HTTPX → Gobuster → Nikto → report  
Includes colorful ASCII unicorn + full branding.

`chmod +x unicorn_scan.sh` 

`sudo ./unicorn_scan.sh example.com -full`

**Output:**

- Colorful ASCII unicorn in terminal
  
- Naabu port scan
  
- Nmap scan on discovered ports (purple)
  
- HTTPX probe (green)
  
- Gobuster scan (orange)
  
- Nikto scan (red)
  
- Full report saved in: `unicorn_report_<target>_<timestamp>/report.txt`
  

---

**⚡ Fast Scan (Go Build)**  
Quick port scan + Nmap on discovered ports. Minimal output, no HTTP or directories.

`go build -o unicorn_scan unicorn_scan.go sudo ./unicorn_scan example.com`

**Output:**

- Discovered ports
  
- Nmap scan (purple)
  
- Minimal report
  

---

### 4️⃣ Notes

- Customize Gobuster wordlist in the script: `/usr/share/wordlists/dirb/common.txt`
  
- Fast scan: Perfect for quick recon
  
- Full scan: Detailed report + all steps automated
  

---

### 5️⃣ Example Workflow

`# Fast scan first sudo ./unicorn_scan example.com # If interesting ports found, run full recon sudo ./unicorn_scan.sh example.com -full # Check detailed report cat unicorn_report_example.com_20250828_231403/report.txt`

---

### Acknowledgments

For my daughter — this unicorn theme is dedicated to you. 🦄

