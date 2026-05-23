# Static IP Configurator

An interactive bash script to configure a static IP address on an Ethernet interface. Automatically detects your distro and uses the appropriate network backend.

## Supported Systems

| Distro | Backend | Config location |
|---|---|---|
| Ubuntu 22.04 / 24.04 / 26.x | Netplan | `/etc/netplan/99-static-<iface>.yaml` |
| Debian / Pop!\_OS / Linux Mint | Netplan | `/etc/netplan/99-static-<iface>.yaml` |
| Arch Linux | systemd-networkd | `/etc/systemd/network/20-static-<iface>.network` |
| Manjaro / EndeavourOS / Garuda | systemd-networkd | `/etc/systemd/network/20-static-<iface>.network` |
| Unknown distro | Auto-detected | whichever backend is available |

## Usage

> **Note:** If the script is stored on an NTFS/exFAT mount (e.g. `/mnt/...`), `chmod +x` won't work. Always run it with `bash` directly:

```bash
sudo bash create-static.sh
```

The script is fully interactive — it will prompt you for:

1. Which network interface to configure (listed with current state and IP)
2. Static IP address (e.g. `192.168.1.100`)
3. Subnet prefix length (e.g. `24` for a `/24` network)
4. Default gateway (e.g. `192.168.1.1`)
5. DNS servers, space-separated (defaults to `8.8.8.8 1.1.1.1`)

After showing a preview of the generated config, it asks for confirmation before applying.

## What it does

- Detects your distro from `/etc/os-release`
- Lists all available network interfaces with their current IP and link state
- Validates all IP inputs before writing anything
- Backs up any existing config file before overwriting
- Sets `chmod 600` on the config file (required by Netplan, good practice for networkd)
- On **Arch**: automatically handles conflicts with `NetworkManager` and `dhcpcd`, and restarts `systemd-resolved` if present
- On **Ubuntu**: validates the config with `netplan generate` before applying; rolls back on failure

## Reverting to DHCP

**Ubuntu / Debian:**
```bash
sudo rm /etc/netplan/99-static-<iface>.yaml
sudo netplan apply
```

**Arch Linux:**
```bash
sudo rm /etc/systemd/network/20-static-<iface>.network
sudo systemctl restart systemd-networkd
```

Replace `<iface>` with your interface name, e.g. `ens18`, `eth0`, `enp3s0`.

## SSH warning

If you apply the config over SSH, **your session will drop** when the network restarts. Reconnect using the new static IP you configured.

## Requirements

- Bash 4+
- `iproute2` (`ip` command) — present on all modern distros
- Root / sudo access
