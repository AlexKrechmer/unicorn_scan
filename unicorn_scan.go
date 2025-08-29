package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
)

// Color codes
const (
	Reset  = "\033[0m"
	Red    = "\033[31m"
	Green  = "\033[32m"
	Cyan   = "\033[36m"
	Purple = "\033[35m"
)

// ==== PRINT BANNERS ====
func printBanners(target string) {
	unicornArt := `
⠀⠀⠀⠀⠀⠑⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠙⢷⣦⣀⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣷⣿⣾⣿⣧⣄⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣇⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣥⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⠟⠉⠉⢹⣿⣿⣿⣿⣿⣿⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⣠⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀⠀⠀⠀⠀⠀
⢀⣴⠿⠛⠉⢸⡏⠁⠉⠙⠛⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣄⡀⠀⠀⠀⠀⠀
⠉⠉⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀
⠀⠀⠀⠀⠀⠈⠿⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠻⢿⣿⣿⣿⣿⣿⣿⣧⡀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⣿⠟⢿⣷⡄
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⡟⠀⢠⣾⣿⣿
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣿⣿⣀⣾⣿⡿⠃
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⠏
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣿⣿⠻⣿⣿⡀

`
	fmt.Println(Purple + unicornArt + Reset)
	fmt.Println(Purple + naabuBanner + Reset)
	fmt.Printf("%s[*] Scanning target: %s%s\n\n", Purple, target, Reset)
}

// ==== RUN NAABU FULL TCP (JSON) ====
func runNaabuFull(target string, minRate int, useSudo bool) []string {
	fmt.Println(Cyan + "[*] Starting full Naabu sweep..." + Reset)
	openPortsFile := "open_ports.txt"

	args := []string{"-host", target, "-p", "-", "-json", "--rate", strconv.Itoa(minRate), "-o", openPortsFile}
	var cmd *exec.Cmd
	if useSudo {
		cmd = exec.Command("sudo", append([]string{"naabu"}, args...)...)
	} else {
		cmd = exec.Command("naabu", args...)
	}

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Println(Red+"[!] Naabu scan failed:", err, Reset)
		return nil
	}

	content, err := os.ReadFile(openPortsFile)
	if err != nil {
		fmt.Println(Red+"[!] Failed to read open ports file:", err, Reset)
		return nil
	}

	portSet := make(map[int]bool)
	scanner := bufio.NewScanner(strings.NewReader(string(content)))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, `"port":`) {
			parts := strings.Split(line, `"port":`)
			if len(parts) < 2 {
				continue
			}
			portPart := strings.SplitN(parts[1], ",", 2)[0]
			portNum, err := strconv.Atoi(strings.TrimSpace(portPart))
			if err == nil {
				portSet[portNum] = true
			}
		}
	}

	openPorts := []int{}
	for p := range portSet {
		openPorts = append(openPorts, p)
	}
	sort.Ints(openPorts)

	openPortsStr := []string{}
	for _, p := range openPorts {
		openPortsStr = append(openPortsStr, strconv.Itoa(p))
	}

	if len(openPortsStr) > 0 {
		fmt.Println(Green+"[*] Naabu found ports:", strings.Join(openPortsStr, ", "), Reset)
	} else {
		fmt.Println(Red + "[!] No open ports found, will default to full TCP scan in Nmap." + Reset)
	}

	return openPortsStr
}

// ==== RUN NMAP FULL SCAN ====
func runNmapFull(target string, ports []string, useSudo bool, timing int) {
	args := []string{"-A", "-T" + strconv.Itoa(timing)}
	if len(ports) > 0 {
		args = append(args, "-p", strings.Join(ports, ","))
		fmt.Printf(Green+"[+] Open ports for Nmap: %s%s\n", strings.Join(ports, ","), Reset)
	} else {
		args = append(args, "-p-", target)
	}

	args = append(args, target)
	var cmd *exec.Cmd
	if useSudo {
		cmd = exec.Command("sudo", append([]string{"nmap"}, args...)...)
	} else {
		cmd = exec.Command("nmap", args...)
	}

	fmt.Println(Cyan + "[*] Running Nmap full scan..." + Reset)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Println(Red+"[!] Nmap scan failed:", err, Reset)
	}
}

// ==== MAIN ====
func main() {
	target := flag.String("target", "", "Target IP or hostname")
	minRate := flag.Int("min-rate", 5000, "Naabu minimum rate")
	useSudo := flag.Bool("sudo", true, "Use sudo for scans")
	timing := flag.Int("T", 5, "Nmap timing template (0-5)")
	flag.Parse()

	// Support positional args
	if *target == "" && len(flag.Args()) > 0 {
		*target = flag.Args()[0]
	}
	if *target == "" {
		fmt.Println(Red + "[!] Please specify a target" + Reset)
		os.Exit(1)
	}

	if *useSudo && os.Geteuid() != 0 {
		fmt.Println(Red + "[!] Root required for full scan. Run with sudo." + Reset)
		os.Exit(1)
	}

	printBanners(*target)

	openPorts := runNaabuFull(*target, *minRate, *useSudo)
	runNmapFull(*target, openPorts, *useSudo, *timing)

	fmt.Println(Green + "[+] Full Naabu + Nmap scan complete." + Reset)
}
