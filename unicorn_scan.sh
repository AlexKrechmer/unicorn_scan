#!/bin/bash

TARGET=$1
FULL=$2
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="reports/unicorn_report_${TARGET}_${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

# ===== Colors =====
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ===== Unicorn Brand =====
PINK='\033[1;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${YELLOW}⠀⠀⠀⠀⠑⢦⡀${PINK}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀${PINK}⠙⢷⣦⣀⠀⡀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀${PINK}⠈⢿⣷⣿⣾⣿⣧⣄⠀⡀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀${PINK}⣰⣿⣿⣿⣿⣿⣿⣿⣇⡀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢀${PINK}⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣥${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠸${PINK}⣿⠟⠉⠉⢹⣿⣿⣿⣿⣿⣿⣀${CYAN}⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠${PINK}⣿⣿⣿⣿⣿⣿⣿${NC}"

echo -e "${YELLOW}             _                                              
${PINK} /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __  
/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _\` | '_ \ 
${CYAN}\ \_/ / | | | | (_| (_) | |  | | | |   \__ \ (_| (_| | | | |
${WHITE} \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|
                                  |_____|${NC}"
# ====================
# Detect Go httpx binary
# ====================
HTTPX_BIN=""
if command -v httpx >/dev/null 2>&1; then
    if httpx -version 2>&1 | grep -q "Current httpx version"; then
        HTTPX_BIN=$(command -v httpx)
    elif [ -f "$HOME/go/bin/httpx" ]; then
        HTTPX_BIN="$HOME/go/bin/httpx"
    else
        echo "[!] Go httpx binary not found. HTTPX scan will be skipped."
    fi
elif [ -f "$HOME/go/bin/httpx" ]; then
    HTTPX_BIN="$HOME/go/bin/httpx"
else
    echo "[!] Go httpx binary not found. HTTPX scan will be skipped."
fi

# ====================
# Naabu Port Scan
# ====================
echo "[*] Running Naabu..."
NAABU_OUTPUT="$REPORT_DIR/naabu.txt"
naabu -host "$TARGET" > "$NAABU_OUTPUT"

echo "====================" >> "$REPORT_DIR/report.txt"
echo "Naabu Port Scan" >> "$REPORT_DIR/report.txt"
cat "$NAABU_OUTPUT" >> "$REPORT_DIR/report.txt"

# Extract ports only (comma-separated)
PORTS=$(grep -oE '[0-9]+' "$NAABU_OUTPUT" | tr '\n' ',' | sed 's/,$//')

# ====================
# Nmap Scan
# ====================
echo -e "${GREEN}
====================================================
     ______                       
       _  \.--------.---.-.-----.
    |.  |   |        |  _  |  _  |
    |.  |   |__|__|__|___._|   __|
    |:  |   |              |__|   
    |::.|   |                     
                         
         Nmap Scan
====================================================
${NC}"

echo "[*] Running Nmap..."
NMAP_OUTPUT="$REPORT_DIR/nmap.txt"
nmap -p "$PORTS" "$TARGET" -oN "$NMAP_OUTPUT"
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Nmap Scan on Discovered Ports: $PORTS" >> "$REPORT_DIR/report.txt"
cat "$NMAP_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# HTTPX + Gobuster Phase
# ====================
echo -e "${YELLOW}
====================================================
 _    _ _   _             
| |  | | | | |            
| |__| | |_| |_ _ ____  __
|  __  | __| __| '_ \ \/ /
| |  | | |_| |_| |_) >  < 
|_|  |_|\__|\__| .__/_/\_\\
                | |        
                |_|        
====================================================
${NC}"

echo "[*] Running HTTPX..."
HTTPX_OUTPUT="$REPORT_DIR/httpx.txt"

if [ -n "$HTTPX_BIN" ]; then
    cat "$NAABU_OUTPUT" | $HTTPX_BIN -silent -o "$HTTPX_OUTPUT"
    echo "[*] HTTPX results saved to $HTTPX_OUTPUT"
    echo "====================" >> "$REPORT_DIR/report.txt"
    echo "HTTPX Scan" >> "$REPORT_DIR/report.txt"
    cat "$HTTPX_OUTPUT" >> "$REPORT_DIR/report.txt"
else
    echo "[!] HTTPX scan skipped."
    touch "$HTTPX_OUTPUT"
fi

# ====================
# Gobuster Scan
# ====================
echo -e "${MAGENTA}
====================================================
                __               __           
   ____ _____  / /_  __  _______/ /____  _____
  / __ \`/ __ \/ __ \/ / / / ___/ __/ _ \/ ___/
 / /_/ / /_/ / /_/ / /_/ (__  ) /_/  __/ /    
 \__, /\____/_.___/\__,_/____/\__/\___/_/     
/____/                                         
====================================================
${NC}"

echo "[*] Running Gobuster..."
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Gobuster Directory Scan" >> "$REPORT_DIR/report.txt"

if [ -s "$HTTPX_OUTPUT" ]; then
    URLS=$(awk '{print $1}' "$HTTPX_OUTPUT" | sort -u)
    for URL in $URLS; do
        GOBUSTER_FILE="$REPORT_DIR/gobuster_$(echo $URL | sed 's/[:\/]/_/g')"
        gobuster dir -u "$URL" -w /usr/share/wordlists/dirb/common.txt -t 10 -o "$GOBUSTER_FILE"
        cat "$GOBUSTER_FILE" >> "$REPORT_DIR/report.txt"
    done
else
    echo "[!] No HTTP URLs found. Skipping Gobuster."
fi

echo "===================="
echo "[*] Unicorn Scan Complete. Full report: $REPORT_DIR/report.txt"