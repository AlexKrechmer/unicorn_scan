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
    echo "           _                                               "
    echo " /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ "
    echo "/ / \ \ '_ \| |/ __/ _ \| '__| '_ \   / __|/ __/ _\` | '_ \\"
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
echo "      ___  ___ ____ _/ /  __ __"
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
echo -e "${BLUE}
====================================================
    __    __  __                      
   / /_  / /_/ /_____  _  __          
  / __ \/ __/ __/ __ \| |/_/          
 / / / /_/ /_/ /_/ />  <            
/_/ /_/\__/\__/ .___/_/|_|            
             /_/                      
====================================================
${NC}"

declare -A HTTPX_MAP
HTTP_PORTS=(80 443)

for port in "${PORTS[@]}"; do
    for proto in http https; do
        # Only default ports can omit :port
        if [[ "$port" -eq 80 && "$proto" == "http" ]] || [[ "$port" -eq 443 && "$proto" == "https" ]]; then
            HTTPX_MAP["$proto://$TARGET"]="$port"
        else
            HTTPX_MAP["$proto://$TARGET:$port"]="$port"
        fi
    done
done

# Run HTTPX
if [[ ${#HTTPX_MAP[@]} -gt 0 ]]; then
    HTTPX_OUTPUT=()
    for url in "${!HTTPX_MAP[@]}"; do
        out=$("$HTTPX_BIN" -silent -timeout 5 -status-code -title -u "$url" 2>/dev/null)
        if [[ -n "$out" ]]; then
            HTTPX_OUTPUT+=("$url")
        fi
    done

    if [[ ${#HTTPX_OUTPUT[@]} -eq 0 ]]; then
        echo -e "${YELLOW}[!] HTTPX returned nothing, using fallback URLs${NC}"
        HTTPX_OUTPUT=("${!HTTPX_MAP[@]}")
    fi
else
    echo -e "${RED}[!] No candidate HTTP URLs found${NC}"
    exit 1
fi

# ====================
# Gobuster Phase
# ====================
echo -e "${BLUE}
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
for url in "${HTTPX_OUTPUT[@]}"; do
    for wordlist in "${WORDLISTS[@]}"; do
        TMP_GOB="$TMP_DIR/gobuster_$(echo "$url" | sed 's/[:\/]/_/g')_$(basename "$wordlist")"
        "$GOBUSTER_BIN" dir -u "$url" -w "$wordlist" -q -o "$TMP_GOB" 2>/dev/null || continue
        if [[ -s "$TMP_GOB" ]]; then
            GOBUSTER_RESULTS["$url"]+=$(cat "$TMP_GOB")$'\n'
            TMP_FILES+=("$TMP_GOB")
        fi
    done
done

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

declare -A NUCLEI_RESULTS
for url in "${HTTPX_OUTPUT[@]}"; do
    TMP_NUC="$TMP_DIR/nuclei_$(echo "$url" | sed 's/[:\/]/_/g')"
    TMP_FILES+=("$TMP_NUC")
    "$NUCLEI_BIN" -u "$url" -silent -o "$TMP_NUC" 2>/dev/null || {
        echo -e "${YELLOW}[!] Nuclei scan had issues for $url${NC}"
    }
    if [[ -s "$TMP_NUC" ]]; then
        NUCLEI_RESULTS["$url"]="$(cat "$TMP_NUC")"
    fi
done


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

if [[ ${#HTTPX_MAP[@]} -gt 0 ]]; then
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
