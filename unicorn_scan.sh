
#!/bin/bash
# unicorn_scan.sh - Automated Recon Script
# By Alex 🦄

# ====================
# Colors
# ====================
NC="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
ORANGE="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"

TARGET=$1
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="unicorn_report_${TARGET}_${TIMESTAMP}"

mkdir -p "$REPORT_DIR"

echo "[*] Starting Unicorn Scan on $TARGET"
echo "[*] Reports will be saved to $REPORT_DIR"

# ====================
# Naabu Fast Scan
# ====================
echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE} _   _    _    ____  _   _ _   _ ${NC}"
echo -e "${BLUE}| \\ | |  / \\  | __ )| | | | \\ | |${NC}"
echo -e "${BLUE}|  \\| | / _ \\ |  _ \\| | | |  \\| |${NC}"
echo -e "${BLUE}| |\\  |/ ___ \\| |_) | |_| | |\\  |${NC}"
echo -e "${BLUE}|_| \\_/_/   \\_\\____/ \\___/|_| \\_|${NC}"
echo -e "${BLUE}====================================================${NC}"

NAABU_OUTPUT="$REPORT_DIR/naabu.txt"
naabu -host "$TARGET" -o "$NAABU_OUTPUT"
PORTS=$(awk -F: '{print $2}' "$NAABU_OUTPUT" | tr '\n' ',' | sed 's/,$//')

echo "[*] Naabu results saved to $NAABU_OUTPUT"
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Naabu Fast Scan" >> "$REPORT_DIR/report.txt"
cat "$NAABU_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# Nmap Phase
# ====================
echo -e "${ORANGE}====================================================${NC}"
echo -e "${ORANGE} ______ _             ${NC}"
echo -e "${ORANGE} \.--------.---.-.-----.${NC}"
echo -e "${ORANGE} |. | | | _ | _ |${NC}"
echo -e "${ORANGE} |. | |__|__|__|___._| __|${NC}"
echo -e "${ORANGE} |: | | |__| |::.| |${NC}"
echo -e "${ORANGE}====================================================${NC}"

echo "[*] Running Nmap..."
NMAP_OUTPUT="$REPORT_DIR/nmap.txt"
nmap -p "$PORTS" "$TARGET" -oN "$NMAP_OUTPUT"

echo "[*] Nmap results saved to $NMAP_OUTPUT"
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Nmap Scan on Discovered Ports: $PORTS" >> "$REPORT_DIR/report.txt"
cat "$NMAP_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# HTTPX Phase
# ====================
echo -e "${PURPLE}====================================================${NC}"
echo -e "${PURPLE}         _____  _____  _____  __${NC}"
echo -e "${PURPLE}  /\\  /\\/${BLUE}__   \\/__   \\/ _ \\ \\/ /${NC}"
echo -e "${PURPLE} / /_/ /  / /\\/  / /\\/ /_)/\\  / ${NC}"
echo -e "${PURPLE}/ __  /  / /    / / / ___/ /  \\ ${NC}"
echo -e "${PURPLE}\\/ /_/   \\/     \\/  \\/    /_/\\_\\${NC}"
echo -e "${PURPLE}====================================================${NC}"

echo "[*] Running HTTPX..."
HTTPX_OUTPUT="$REPORT_DIR/httpx.txt"
if command -v httpx >/dev/null 2>&1; then
    cat "$NAABU_OUTPUT" | httpx -silent -o "$HTTPX_OUTPUT"
    echo "[*] HTTPX results saved to $HTTPX_OUTPUT"
    echo "====================" >> "$REPORT_DIR/report.txt"
    echo "HTTPX Scan" >> "$REPORT_DIR/report.txt"
    cat "$HTTPX_OUTPUT" >> "$REPORT_DIR/report.txt"
else
    echo "[!] HTTPX not found. Skipping."
    touch "$HTTPX_OUTPUT"
fi

# ====================
# Gobuster Phase
# ====================
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  .,-:::::/      ...     :::::::.   ...    ::: .::::::.::::::::::::.,:::::: :::::::..   ${NC}"
echo -e "${GREEN},;;-'````'    .;;;;;;;.   ;;;'';;'  ;;     ;;;;;;`    \`;;;;;;;;'''';;;;'''' ;;;;``;;;;  ${NC}"
echo -e "${GREEN}[[[   [[[[[[/,[[     \[[, [[[__[[\\.[['     [[['[==/[[[[,    [[      [[cccc   [[[,/[[['   ${NC}"
echo -e "${GREEN}\"$$c.    \"$$ $$$,     $$$ $$\"\"\"\"Y$$$$      $$$  '''    $    $$      $$\"\"\"\"   $$$$$$c    ${NC}"
echo -e "${GREEN} \`Y8bo,,,o88o\"888,_ _,88P_88o,,od8P88    .d888 88b    dP    88,     888oo,__ 888b \"88bo, ${NC}"
echo -e "${GREEN}   `'YMUP\"YMM  \"YMMMMMP\" \"\"YUMMMP\"  \"YmmMMMM\"\"  \"YMmMY\"     MMM     \"\"\"\"YUMMMMMMM   \"W\"  ${NC}"
echo -e "${GREEN}====================================================${NC}"

echo "[*] Running Gobuster..."
GOBUSTER_OUTPUT="$REPORT_DIR/gobuster.txt"
if [ -s "$HTTPX_OUTPUT" ]; then
    while read -r url; do
        gobuster dir -u "$url" -w /usr/share/wordlists/dirb/common.txt -o "$GOBUSTER_OUTPUT"
    done < "$HTTPX_OUTPUT"
    echo "[*] Gobuster results saved to $GOBUSTER_OUTPUT"
    echo "====================" >> "$REPORT_DIR/report.txt"
    echo "Gobuster Scan" >> "$REPORT_DIR/report.txt"
    cat "$GOBUSTER_OUTPUT" >> "$REPORT_DIR/report.txt"
else
    echo "[!] No HTTP services found, skipping Gobuster."
    touch "$GOBUSTER_OUTPUT"
fi

# ====================
# Nikto Phase
# ====================
echo -e "${RED}====================================================${NC}"
echo -e "${RED} _______  .__ __      __          ${NC}"
echo -e "${RED} \\      \\ |__|  | ___/  |_  ____  ${NC}"
echo -e "${RED} /   |   \\|  |  |/ /\\   __\\/  _ \\ ${NC}"
echo -e "${RED}/    |    \\  |    <  |  | (  <_> )${NC}"
echo -e "${RED}\\____|__  /__|__|_ \\ |__|  \\____/ ${NC}"
echo -e "${RED}        \\/        \\/              ${NC}"
echo -e "${RED}====================================================${NC}"

echo "[*] Running Nikto..."
NIKTO_OUTPUT="$REPORT_DIR/nikto.txt"
if command -v nikto >/dev/null 2>&1; then
    if [ -s "$HTTPX_OUTPUT" ]; then
        while read -r url; do
            echo "[*] Scanning $url with Nikto..."
            nikto -h "$url" >> "$NIKTO_OUTPUT" 2>&1
        done < "$HTTPX_OUTPUT"
    else
        echo "[!] No HTTP services found, skipping Nikto scan."
        touch "$NIKTO_OUTPUT"
    fi
    echo "[*] Nikto results saved to $NIKTO_OUTPUT"
    echo "====================" >> "$REPORT_DIR/report.txt"
    echo "Nikto Scan Results" >> "$REPORT_DIR/report.txt"
    cat "$NIKTO_OUTPUT" >> "$REPORT_DIR/report.txt"
else
    echo "[!] Nikto not found. Skipping."
    touch "$NIKTO_OUTPUT"
fi

echo "[*] Unicorn Scan finished! Reports saved in $REPORT_DIR"
