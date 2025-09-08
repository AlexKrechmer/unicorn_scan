#!/usr/bin/env bash
# unicorn_scan.sh - Full-featured Automated Recon Script (cleaned)
# By Alex 🦄  — revised
set -euo pipefail
IFS=$'\n\t'

# ====================
# Colors
# ====================
NC="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[0;93m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
TEAL="\033[1;36m"
ORANGE="\033[1;33m"

# ====================
# Globals & arrays
# ====================
declare -A HTTPX_MAP
declare -A GOBUSTER_RESULTS
declare -A NUCLEI_RESULTS
TMP_FILES=()
TMP_DIR=""

# ====================
# Script directory
# ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ====================
# Cleanup (single trap)
# ====================
cleanup() {
    local rc=$?
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR" || true
    fi
    for f in "${TMP_FILES[@]:-}"; do
        [[ -e "$f" ]] && rm -f "$f" || true
    done
    exit $rc
}
trap cleanup EXIT

# ====================
# Tool finder (search common locations / PATH)
# ====================
find_tool() {
    local tool=$1
    local candidates=(
        "$SCRIPT_DIR/bin/$tool"
        "$HOME/go/bin/$tool"
        "/usr/local/bin/$tool"
        "/usr/bin/$tool"
        "/bin/$tool"
    )
    for p in "${candidates[@]}"; do
        [[ -x "$p" ]] && { echo "$p"; return 0; }
    done
    if command -v "$tool" >/dev/null 2>&1; then
        command -v "$tool"
        return 0
    fi
    echo ""
}

NAABU_BIN=$(find_tool naabu)
NMAP_BIN=$(find_tool nmap)
HTTPX_BIN=$(find_tool httpx)
GOBUSTER_BIN=$(find_tool gobuster)
NUCLEI_BIN=$(find_tool nuclei)
GIT_BIN=$(find_tool git)

# ====================
# Target
# ====================
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    echo -e "${RED}[!] Usage: $0 <target>${NC}"
    exit 1
fi

# ====================
# Wordlists
# ====================
WORDLIST_DIR="$SCRIPT_DIR/wordlists"
mkdir -p "$WORDLIST_DIR"

SMALL_WL="$WORDLIST_DIR/raft-small-directories.txt"
QUICKHIT_WL="$WORDLIST_DIR/quickhits.txt"
MEDIUM_WL="$WORDLIST_DIR/raft-medium-directories.txt"
COMMON_WL="$WORDLIST_DIR/common.txt"

if [[ ! -f "$SMALL_WL" || ! -f "$QUICKHIT_WL" || ! -f "$MEDIUM_WL" || ! -f "$COMMON_WL" ]]; then
    if [[ -n "$GIT_BIN" ]]; then
        echo -e "${YELLOW}[*] Wordlists missing, cloning SecLists...${NC}"
        TMP_DIR=$(mktemp -d)
        TMP_FILES+=("$TMP_DIR")
        git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$TMP_DIR/tmp_sec" >/dev/null 2>&1 || {
            echo -e "${RED}[!] Failed to clone SecLists. Check network/git.${NC}"
        }
        if [[ -d "$TMP_DIR/tmp_sec" ]]; then
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/raft-small-directories.txt" "$SMALL_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/quickhits.txt" "$QUICKHIT_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/raft-medium-directories.txt" "$MEDIUM_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/common.txt" "$COMMON_WL" 2>/dev/null || true
            rm -rf "$TMP_DIR/tmp_sec"
        else
            echo -e "${YELLOW}[!] SecLists not available — continuing without cloning.${NC}"
        fi
    else
        echo -e "${YELLOW}[!] git not found and wordlists missing — continuing.${NC}"
    fi
else
    echo -e "${GREEN}[*] Wordlists already present.${NC}"
fi

WORDLISTS=()
for wl in "$SMALL_WL" "$QUICKHIT_WL" "$MEDIUM_WL" "$COMMON_WL"; do
    [[ -f "$wl" ]] && WORDLISTS+=("$wl")
done

# ====================
# ASCII Banner
# ====================
print_banner() {
    echo -e "${YELLOW}${TEAL}$"
    echo "             _                                               "
    echo " /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ "
    echo "/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _\` | '_ \\"
    echo "\ \_/ / | | | | (_| (_) | |  | | |     \__ \ (_| (_| | | | | "
    echo " \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|"
    echo "                                  |_____|                  "
    echo -e "${NC}"
}
print_banner
echo -e "${GREEN}[*] Starting Unicorn Scan on $TARGET${NC}"

# Create a dedicated temp dir for per-run files
TMP_DIR="${TMP_DIR:-$(mktemp -d)}"
TMP_FILES+=("$TMP_DIR")

# ====================
# Naabu Phase
# ====================
echo -e "${PURPLE}"
echo "===================================================="
echo "                  __       "
echo "  ___  ___ ____ _/ /  __ __"
echo " / _ \/ _ \/ _ \/ _ \/ // /"
echo "/_//_/\_,_/\_,_/_.__/\_,_/ "
echo "===================================================="
echo -e "${NC}"

PORTS=""
if [[ -n "$NAABU_BIN" ]]; then
    echo -e "${BLUE}[*] Running Naabu to discover open ports...${NC}"
    # using -silent for compact output; expect lines like host:port
    NAABU_OUT="$TMP_DIR/naabu.out"
    TMP_FILES+=("$NAABU_OUT")
    "$NAABU_BIN" -host "$TARGET" -silent 2>/dev/null | awk -F: '{print $2?$2:$1}' | sort -n -u > "$NAABU_OUT" || true
    if [[ -s "$NAABU_OUT" ]]; then
        PORTS=$(paste -sd, "$NAABU_OUT")
        echo -e "${GREEN}[*] Discovered ports: $PORTS${NC}"
    else
        echo -e "${YELLOW}[!] Naabu found no ports or failed.${NC}"
    fi
else
    echo -e "${RED}[!] Naabu not found, skipping port discovery.${NC}"
fi

# ====================
# Nmap Phase
# ====================
echo -e "${YELLOW}"
echo "===================================================="
echo " .-----.--------.---.-.-----."
echo " |     |        |  _  |  _  |"
echo " |__|__|__|__|__|___._|   __|"
echo "                      |__|   "
echo "===================================================="
echo -e "${NC}"

if [[ -n "$PORTS" && -n "$NMAP_BIN" ]]; then
    NMAP_TMP="$TMP_DIR/nmap.out"
    TMP_FILES+=("$NMAP_TMP")
    echo -e "${ORANGE}[*] Running Nmap on discovered ports...${NC}"
    # -Pn omitted so hosts that block ping can still be checked if you want add -Pn
    "$NMAP_BIN" -p "$PORTS" -sV "$TARGET" | tee "$NMAP_TMP"
else
    if [[ -z "$PORTS" ]]; then
        echo -e "${YELLOW}[!] No ports discovered; skipping targeted Nmap scan.${NC}"
    else
        echo -e "${RED}[!] Nmap missing, skipping Nmap phase.${NC}"
    fi
fi

# Generate HTTP URLs from discovered ports
HTTP_URLS=""
if [[ -n "$PORTS" ]]; then
    for p in ${PORTS//,/ }; do
        proto="http"
        host="$TARGET"
        # Treat common TLS ports as https
        if [[ "$p" == "443" || "$p" == "8443" || "$p" == "7443" ]]; then
            proto="https"
        fi
        # only append :port if not default for proto
        if { [[ "$proto" == "http" && "$p" != "80" ]] || [[ "$proto" == "https" && "$p" != "443" ]]; }; then
            host="$TARGET:$p"
        fi
        HTTP_URLS+="$proto://$host"$'\n'
    done
    HTTP_URLS=$(echo "$HTTP_URLS" | sed '/^\s*$/d' | sort -u)
fi

# ====================
# HTTPX Phase
# ====================
print_httpx_banner() {
    echo -e "${GREEN}
====================================================
    __    __  __                      
   / /_  / /_/ /_____  _  __          
  / __ \/ __/ __/ __ \| |/_/          
 / / / /_/ /_/ /_/ /   >  <            
/_/ /_/\__/\__/ .___/_/|_|            
             /_/                      
====================================================
${NC}"
}

# Call the banner
print_httpx_banner

# Declare arrays for URLs and results
declare -a HTTP_URLS
declare -A HTTPX_RESULTS

# Populate URLs from previous scan output (assume TMP_NMAP contains hosts)
while read -r ip port; do
    # Only HTTP/S ports
    if [[ "$port" == "80" || "$port" == "443" || "$port" =~ ^8[0-9]{2,3}$ || "$port" == "8080" ]]; then
        proto="http"
        [[ "$port" == "443" ]] && proto="https"
        [[ "$port" == "8443" ]] && proto="https"
        HTTP_URLS+=("$proto://$ip:$port")
    fi
done < "$TMP_NMAP"

# Run HTTPX in parallel
for url in "${HTTP_URLS[@]}"; do
    TMP_HTTP="$TMP_DIR/httpx_$(echo "$url" | sed 's/[:\/]/_/g')"
    TMP_FILES+=("$TMP_HTTP")
    
    "$HTTPX_BIN" -silent -title -status-code -l "$url" \
    | tee "$TMP_HTTP" | while read -r line; do
        echo -e "${GREEN}[HTTPX] $line${NC}"
        HTTPX_RESULTS["$url"]+="$line"$'\n'
    done &
done

# Wait for all HTTPX jobs to finish
wait
# ====================
# Gobuster Phase
# ====================
echo -e "${PURPLE}
====================================================
  _____       _               _            
 |  __ \     | |             | |           
 | |  \/ ___ | |__  _   _ ___| |_ ___ _ __ 
 | | __ / _ \| '_ \| | | / __| __/ _ \ '__|
 | |_\ \ (_) | |_) | |_| \__ \ ||  __/ |   
  \____/\___/|_.__/ \__,_|___/\__\___|_|   
====================================================
${NC}"
declare -A GOBUSTER_RESULTS

# Check prerequisites
if [[ -z "$GOBUSTER_BIN" ]] || ! command -v "$GOBUSTER_BIN" &>/dev/null; then
    echo -e "${RED}[!] Gobuster binary not found. Skipping Gobuster phase.${NC}"
elif [[ ${#HTTP_URLS[@]} -eq 0 || ${#WORDLISTS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}[!] Gobuster skipped: No URLs or wordlists provided.${NC}"
else
    echo -e "${PURPLE}[+] Starting Gobuster scans...${NC}"
    
    for url in "${HTTP_URLS[@]}"; do
        for wordlist in "${WORDLISTS[@]}"; do
            {
                WORDLIST_NAME=$(basename "$wordlist")
                echo -e "${TEAL}[Gobuster] Scanning $url with $WORDLIST_NAME${NC}"
                
                TMP_GOB="$TMP_DIR/gobuster_$(echo "$url" | sed 's/[:\/]/_/g')_$WORDLIST_NAME"
                
                "$GOBUSTER_BIN" dir -u "$url" -w "$wordlist" -t 30 -q 2>/dev/null \
                | tee "$TMP_GOB" | while read -r line; do
                    echo -e "${TEAL}[Gobuster][$url|$WORDLIST_NAME] $line${NC}"
                    GOBUSTER_RESULTS["$url"]+="$line"$'\n'
                done

                # Save temporary results for later use
                [[ -s "$TMP_GOB" ]] && TMP_FILES+=("$TMP_GOB")
            } &
        done
    done
    wait
    echo -e "${PURPLE}[+] Gobuster phase completed.${NC}"
fi

# ====================
# Nuclei Phase
# ====================
echo -e "${BLUE}
====================================================
                     .__         .__ 
  ____  __ __   ____ |  |   ____ |__|
 /    \|  |  \_/ ___\|  | _/ __ \|  |
|   |  \  |  /\  \___|  |_\  ___/|  |
|___|  /____/  \___  >____/\___  >__|
     \/            \/          \/    
====================================================
${NC}"

echo -e "${ORANGE}==================== Nuclei Phase ====================${NC}"

declare -A NUCLEI_RESULTS

# Ensure NUCLEI_TEMPLATES exists, even if empty
NUCLEI_TEMPLATES=()

# Make sure we have URLs and nuclei binary
if [[ ${#HTTP_URLS[@]} -gt 0 && command -v "$NUCLEI_BIN" &>/dev/null ]]; then

    for url in "${HTTP_URLS[@]}"; do
        {
            echo -e "${ORANGE}[Nuclei] Scanning $url${NC}"

            TMP_NUC="$TMP_DIR/nuclei_$(echo "$url" | sed 's/[:\/]/_/g')"
            TMP_FILES+=("$TMP_NUC")

            # Run nuclei with or without specific templates
            if [[ ${#NUCLEI_TEMPLATES[@]} -gt 0 ]]; then
                "$NUCLEI_BIN" -u "$url" $(printf -- "-t %s " "${NUCLEI_TEMPLATES[@]}") -silent \
                | tee "$TMP_NUC" | while read -r line; do
                    echo -e "${GREEN}[Nuclei] $line${NC}"
                    NUCLEI_RESULTS["$url"]+="$line"$'\n'
                done
            else
                "$NUCLEI_BIN" -u "$url" -silent \
                | tee "$TMP_NUC" | while read -r line; do
                    echo -e "${GREEN}[Nuclei] $line${NC}"
                    NUCLEI_RESULTS["$url"]+="$line"$'\n'
                done
            fi
        } &
    done

    # Wait for all background scans to finish
    wait

else
    echo -e "${YELLOW}[!] Nuclei skipped: missing URLs or binary.${NC}"
fi

echo -e "${YELLOW}[!] HTTPX → Gobuster → Nuclei processing complete.${NC}"

# ====================
# Summary
# ====================
echo -e "${GREEN}
====================================================
UNICORN SCAN SUMMARY
Target: $TARGET
Open Ports: ${PORTS:-None}
====================================================
HTTP URLs Discovered:
${NC}"

if [[ ${#HTTP_URLS[@]} -gt 0 ]]; then
    for url in "${!HTTPX_MAP[@]}"; do
        echo "$url -> ${HTTPX_MAP[$url]}"
    done
else
    echo -e "${YELLOW}[!] No HTTP URLs found.${NC}"
fi

echo -e "\nGobuster Results:"
if [[ ${#GOBUSTER_RESULTS[@]} -gt 0 ]]; then
    for url in "${!GOBUSTER_RESULTS[@]}"; do
        echo "$url:"
        echo -e "${GOBUSTER_RESULTS[$url]}"
    done
else
    echo -e "${YELLOW}[!] No Gobuster results.${NC}"
fi

echo -e "\nNuclei Results:"
if [[ ${#NUCLEI_RESULTS[@]} -gt 0 ]]; then
    for url in "${!NUCLEI_RESULTS[@]}"; do
        echo "$url:"
        echo -e "${NUCLEI_RESULTS[$url]}"
    done
else
    echo -e "${YELLOW}[!] No Nuclei results.${NC}"
fi

echo -e "
Wordlists Used: ${WORDLISTS[*]:-None}
====================================================
[*] Unicorn Scan finished!
${NC}"
