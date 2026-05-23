#!/bin/bash
# ============================================================
#  run.sh — Run the static IP setup script
# ============================================================

DIR="$(dirname "$0")"
SCRIPT="$DIR/create-static.sh"

echo "How do you want to run the script?"
echo "  [1] bash (works everywhere, incl. NTFS/exFAT mounts) etc."
echo "  [2] direct ./create-static.sh (requires permissions or chmod +x over network drives)"
echo ""
read -rp "Choice [1/2]: " CHOICE

case "$CHOICE" in
    1)
        sudo bash "$SCRIPT"
        ;;
    2)
        sudo chmod +x "$SCRIPT"
        sudo "$SCRIPT"
        ;;
    *)
        echo "Invalid choice. Defaulting to bash..."
        sudo bash "$SCRIPT"
        ;;
esac
