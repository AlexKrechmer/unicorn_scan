# Unicorn Scan 🦄

```bash
# Color codes
PINK='\033[1;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Unicorn ASCII
echo -e "${YELLOW}⠀⠀⠀⠀⠑⢦⡀${PINK}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀${PINK}⠙⢷⣦⣀⠀⡀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀${PINK}⠈⢿⣷⣿⣾⣿⣧⣄⠀⡀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀${PINK}⣰⣿⣿⣿⣿⣿⣿⣿⣇⡀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢀${PINK}⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣥${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠸${PINK}⣿⠟⠉⠉⢹⣿⣿⣿⣿⣿⣿⣀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠${PINK}⣿⣿⣿⣿⣿⣿⣿${NC}"

# Logo text
echo -e "${YELLOW}             _                                              
${PINK} /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __  
/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _\` | '_ \ 
${CYAN}\ \_/ / | | | | (_| (_) | |  | | | |   \__ \ (_| (_| | | | |
${WHITE} \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|
                                  |_____|${NC}"
```

#### Features

- **Fast Scan:** Naabu → Nmap (Go build version)
  
- **Full Recon:** Naabu → Nmap → HTTPX → Gobuster → report generation
  
- **Colorful unicorn ASCII branding** for fun + readability
  
- **Saved reports** for each target in organized folders
  

---

## Quick Start 

### 1️⃣ clone the repo

`git clone https://github.com/AlexKrechmer/unicorn_scan.git `

`cd unicorn_scan`

### 2️⃣ Install dependencies

**Update & essentials:**

`sudo apt update && sudo apt install -y git curl wget nmap`

**Install Go (for Naabu & HTTPX):**


`curl -LO https://go.dev/dl/go1.21.2.linux-amd64.tar.gz` 

`sudo rm -rf /usr/local/go` 

`sudo tar -C /usr/local -xzf go1.21.2.linux-amd64.tar.gz` 

`echo export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin >> ~/.bashrc` 

`source ~/.bashrc`

**Install Naabu & HTTPX:**

`go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest`

`go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest`

**Install Gobuster:**

`sudo apt install -y gobuster`

> After this, `naabu`, `httpx`, `gobuster`, and `nmap` should be available in your PATH.

---

### 3️⃣ Usage Options

#### ⚡ Fast Scan (Go Build)

Quick port scan + Nmap on discovered ports. Minimal output, no HTTP or directories.

# Build the fast scanner 

`go build -o unicorn_scan unicorn_scan.go` 

# Run fast scan 

`sudo ./unicorn_scan example.com`

**Output:**

- Discovered ports
  
- Nmap scan on those ports
  
- Minimal report
  

---

#### 🐴 Full Recon (.sh)

Runs **Naabu → Nmap → HTTPX → Gobuster → report**  
Includes colorful ASCII unicorn + full branding.

# Make script executable 

`chmod +x unicorn_scan.sh` 

# Run full scan

` sudo ./unicorn_scan.sh example.com -full`

**Output:**

- Colorful unicorn ASCII in terminal
  
- Naabu port scan
  
- Nmap scan on discovered ports
  
- HTTPX probe for live HTTP servers
  
- Gobuster directory scan on live HTTP URLs
  
- Full report saved in:  
  `unicorn_report_<target>_<timestamp>/report.txt`
  

---

### 4️⃣ Notes

- Customize Gobuster wordlist in the script:  
  
`/usr/share/wordlists/dirb/common.txt`
  
- **Fast scan:** perfect for quick recon
  
- **Full scan:** detailed report + all steps automated
  

---

### 5️⃣ Example Workflow

# Fast scan first 
`sudo ./unicorn_scan example.com` 

# If interesting ports found, run full recon 

`sudo ./unicorn_scan.sh example.com -full` 

# Check detailed report

`cat unicorn_report_example.com_20250828_231403/report.txt`

# Acknowledgments For my daughter, this unicorn theme is for you.

