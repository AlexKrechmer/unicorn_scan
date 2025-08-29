
#!/bin/bash

TARGET=$1
FULL=$2
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="reports/unicorn_report_${TARGET}_${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

# Default wordlists for Gobuster
DEFAULT_WORDLISTS=(
    "$HOME/Documents/gobuster/SecLists/Discovery/Web-Content/raft-small-words.txt"
    "$HOME/Documents/gobuster/SecLists/Discovery/Web-Content/quickhits.txt"
    "$HOME/Documents/gobuster/SecLists/Discovery/Web-Content/raft-medium-words.txt"
)

# ===== Colors =====
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
PINK='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ===== Unicorn ASCII =====
echo -e

"${YELLOW}⠀⠀⠑⢦⡀${PINK}⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
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
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})

if command -v httpx >/dev/null 2>&1; then
    HTTPX_BIN=$(command -v httpx)
elif [ -f "$USER_HOME/go/bin/httpx" ]; then
    HTTPX_BIN="$USER_HOME/go/bin/httpx"
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

PORTS=$(grep -oE '[0-9]+' "$NAABU_OUTPUT" | tr '\n' ',' | sed 's/,$//')

# ====================
# Nmap Scan
# ====================
echo -e "${GREEN}[*] Running Nmap...${NC}"
NMAP_OUTPUT="$REPORT_DIR/nmap.txt"
nmap -p "$PORTS" "$TARGET" -oN "$NMAP_OUTPUT"

echo "====================" >> "$REPORT_DIR/report.txt"
echo "Nmap Scan on Discovered Ports: $PORTS" >> "$REPORT_DIR/report.txt"
cat "$NMAP_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# HTTPX + Gobuster Phase
# ====================
echo -e "${YELLOW}[*] Running HTTPX...${NC}"
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
# Nikto Scan
# ====================
echo -e "${CYAN}[*] Running Nikto on discovered HTTP services...${NC}"
NIKTO_OUTPUT="$REPORT_DIR/nikto.txt"

if [ -s "$HTTPX_OUTPUT" ]; then
    while read -r URL; do
        echo "[*] Scanning $URL with Nikto..."
        nikto -h "$URL" -output "$REPORT_DIR/nikto_$(echo $URL | sed 's/[:\/]/_/g').txt"
        cat "$REPORT_DIR/nikto_$(echo $URL | sed 's/[:\/]/_/g').txt" >> "$NIKTO_OUTPUT"
        echo "--------------------" >> "$NIKTO_OUTPUT"
    done < <(awk '{print $1}' "$HTTPX_OUTPUT" | sort -u)

    echo "[*] Nikto results saved to $NIKTO_OUTPUT"
    echo "====================" >> "$REPORT_DIR/report.txt"
    echo "Nikto Scan" >> "$REPORT_DIR/report.txt"
    cat "$NIKTO_OUTPUT" >> "$REPORT_DIR/report.txt"
else
    echo "[!] No HTTP URLs found. Skipping Nikto."
    touch "$NIKTO_OUTPUT"
fi

# ====================
# Gobuster Scan (Separate)
# ====================
echo -e "${MAGENTA}[*] Running Gobuster...${NC}"
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Gobuster Directory Scan" >> "$REPORT_DIR/report.txt"

if [ -s "$HTTPX_OUTPUT" ]; then
    URLS=$(awk '{print $1}' "$HTTPX_OUTPUT" | sort -u)
    for URL in $URLS; do
        for WORDLIST in "${DEFAULT_WORDLISTS[@]}"; do
            WL_NAME=$(basename "$WORDLIST")
            GOBUSTER_FILE="$REPORT_DIR/gobuster_${WL_NAME}_$(echo $URL | sed 's/[:\/]/_/g').txt"
            echo "[*] Running Gobuster on $URL with $WL_NAME"
            gobuster dir -u "$URL" -w "$WORDLIST" -t 10 -o "$GOBUSTER_FILE"
            cat "$GOBUSTER_FILE" >> "$REPORT_DIR/report.txt"
            echo "--------------------" >> "$REPORT_DIR/report.txt"
        done
    done
else
    echo "[!] No HTTP URLs found. Skipping Gobuster."
fi
