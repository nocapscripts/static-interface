#!/bin/bash
# ============================================================
#  set_static_ip.sh — Configure Ethernet to Static IP
#  Works on Ubuntu 22.04 / 24.04 / 26.xx (Netplan)
#  Run as root: sudo bash set_static_ip.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: Please run as root → sudo bash $0${NC}"
    exit 1
fi

echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}   Ubuntu Static IP Configurator (Netplan) ${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"

# ── List ethernet interfaces ─────────────────────────────────
echo -e "${YELLOW}Available network interfaces:${NC}"
mapfile -t IFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
for i in "${!IFACES[@]}"; do
    IFACE="${IFACES[$i]}"
    STATUS=$(ip link show "$IFACE" | grep -o 'state [A-Z]*' | awk '{print $2}')
    CURRENT_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet )\S+' || echo "none")
    echo -e "  ${BOLD}[$((i+1))]${NC} ${CYAN}${IFACE}${NC}  — state: ${STATUS}  IP: ${CURRENT_IP}"
done

echo ""
read -rp "$(echo -e "${BOLD}Select interface number: ${NC}")" IFACE_NUM

if ! [[ "$IFACE_NUM" =~ ^[0-9]+$ ]] || (( IFACE_NUM < 1 || IFACE_NUM > ${#IFACES[@]} )); then
    echo -e "${RED}Invalid selection.${NC}"; exit 1
fi

IFACE="${IFACES[$((IFACE_NUM-1))]}"
echo -e "\n${GREEN}Selected: ${BOLD}${IFACE}${NC}\n"

# ── Helper: validate IPv4 ────────────────────────────────────
valid_ip() {
    local ip="$1"
    local IFS='.'
    read -ra PARTS <<< "$ip"
    [[ ${#PARTS[@]} -eq 4 ]] || return 1
    for part in "${PARTS[@]}"; do
        [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 0 && part <= 255 )) || return 1
    done
}

# ── Collect static IP settings ───────────────────────────────
while true; do
    read -rp "$(echo -e "${BOLD}Static IP address (e.g. 192.168.1.100): ${NC}")" STATIC_IP
    valid_ip "$STATIC_IP" && break
    echo -e "${RED}  Invalid IP. Try again.${NC}"
done

while true; do
    read -rp "$(echo -e "${BOLD}Subnet prefix length (e.g. 24 for /24): ${NC}")" PREFIX
    [[ "$PREFIX" =~ ^[0-9]+$ ]] && (( PREFIX >= 1 && PREFIX <= 32 )) && break
    echo -e "${RED}  Invalid prefix. Enter a number 1-32.${NC}"
done

while true; do
    read -rp "$(echo -e "${BOLD}Default gateway (e.g. 192.168.1.1): ${NC}")" GATEWAY
    valid_ip "$GATEWAY" && break
    echo -e "${RED}  Invalid gateway. Try again.${NC}"
done

read -rp "$(echo -e "${BOLD}DNS servers, space-separated (default: 8.8.8.8 1.1.1.1): ${NC}")" DNS_INPUT
DNS_INPUT="${DNS_INPUT:-8.8.8.8 1.1.1.1}"

# Build YAML DNS list
DNS_YAML=""
for dns in $DNS_INPUT; do
    DNS_YAML+="          - ${dns}"$'\n'
done

# ── Locate / create Netplan config ───────────────────────────
NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="${NETPLAN_DIR}/99-static-${IFACE}.yaml"

# Backup any existing file
if [[ -f "$NETPLAN_FILE" ]]; then
    BACKUP="${NETPLAN_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$NETPLAN_FILE" "$BACKUP"
    echo -e "${YELLOW}Backed up existing config → ${BACKUP}${NC}"
fi

# ── Write Netplan YAML ───────────────────────────────────────
cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses:
        - ${STATIC_IP}/${PREFIX}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses:
${DNS_YAML}
EOF

chmod 600 "$NETPLAN_FILE"
echo -e "\n${GREEN}Netplan config written to: ${BOLD}${NETPLAN_FILE}${NC}"
echo -e "\n${YELLOW}Config preview:${NC}"
echo "─────────────────────────────────────────"
cat "$NETPLAN_FILE"
echo "─────────────────────────────────────────"

# ── Apply ────────────────────────────────────────────────────
echo ""
read -rp "$(echo -e "${BOLD}Apply now? This will change your network. (y/N): ${NC}")" CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${CYAN}Validating config...${NC}"
    netplan generate 2>&1 || { echo -e "${RED}Netplan config invalid! Rolling back.${NC}"; rm -f "$NETPLAN_FILE"; exit 1; }

    echo -e "${CYAN}Applying...${NC}"
    netplan apply

    sleep 2
    NEW_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet )\S+' || echo "not assigned yet")
    echo -e "\n${GREEN}${BOLD}Done!${NC} ${IFACE} now has IP: ${BOLD}${NEW_IP}${NC}"
    echo -e "${YELLOW}Tip: if SSH dropped, reconnect to ${STATIC_IP}${NC}"
else
    echo -e "\n${YELLOW}Skipped apply. Run manually:${NC}"
    echo -e "  ${BOLD}sudo netplan apply${NC}"
fi

echo -e "\n${CYAN}To revert to DHCP, delete ${NETPLAN_FILE} and run: sudo netplan apply${NC}\n"
