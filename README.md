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

Automated Recon Script with live output, default wordlists, and colored ASCII fun!

---

## 1️⃣ Clone Repository

```bash

git clone https://github.com/AlexKrechmer/unicorn_scan.git

cd unicorn_scan

2️⃣ Install System Dependencies

sudo apt update

sudo apt install -y git curl wget nmap nikto tar

⚠️ We skip golang-go from apt to avoid conflicts. We’ll install a self-contained Go 1.24.

3️⃣ Install Go Locally

# Download and extract Go 1.24.6 into a local folder

curl -LO https://go.dev/dl/go1.24.6.linux-amd64.tar.gz && mkdir -p go && tar -C go -xzf go1.24.6.linux-amd64.tar.gz --strip-components=1

# Add local Go to PATH for this session

export PATH=$PWD/go/bin:$PWD/bin:$PATH

# Verify installation

go version # should show go1.24.6

This keeps Go inside the project folder—no system conflicts.

4️⃣ Install Naabu & HTTPX Locally


# Create a local bin folder for Go-installed binaries

mkdir -p bin

# Use module-aware mode

export GOPATH=$PWD
export GO111MODULE=on

# Install tools into the local bin

go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/OJ/gobuster/v3@latest

# Confirm binaries

ls bin/
ls -l ~/unicorn_scan/bin/

# Should show 'naabu'. gobster and 'httpx'

5️⃣ Make Script Executable

chmod +x unicorn_scan.sh

6️⃣ Run the Script

./unicorn_scan.sh
All binaries (go, naabu, httpx) are local. No global PATH edits are needed.

✅ Notes
The local go/bin and bin folders contain all executables.

If you open a new shell, run export PATH=$PWD/go/bin:$PWD/bin:$PATH again inside the project folder.

Naabu, HTTPX, Nmap, Gobuster, and Nikto will all work together inside unicorn_scan.sh.
For my daughter — this unicorn theme is dedicated to you. 🦄     
