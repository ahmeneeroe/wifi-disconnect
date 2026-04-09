# wifi-disconnect

A lightweight macOS daemon that automatically disconnects from your iPhone hotspot when you close the lid (sleep), leaving other WiFi connections untouched.

## How it works

- A Swift daemon listens for macOS sleep/wake notifications via a RunLoop (zero CPU when idle, ~15 MB RAM)
- On sleep: detects iPhone hotspot by IP subnet (`172.20.10.0/28`) and disconnects via CoreWLAN
- On wake: re-enables WiFi if it was turned off as a fallback
- SSID pattern matching ("DAAAVID") is a secondary detection method (requires Location Services)

## Files

- `wifi-disconnect.swift` — daemon source
- `install.sh` — compiles, installs binary to `~/.local/bin/`, sets up LaunchAgent
- `uninstall.sh` — stops service, removes binary and plist
- `config.txt` — SSID patterns (one per line), installed to `~/.config/wifi-disconnect/`

## Commands

```bash
# Install / reinstall
cd /Users/papillonm5/Documents/Projects/wifi-disconnect && ./install.sh

# Uninstall
cd /Users/papillonm5/Documents/Projects/wifi-disconnect && ./uninstall.sh

# Check logs
cat ~/.config/wifi-disconnect/disconnect.log

# Check service status
launchctl print gui/$(id -u)/com.user.wifi-disconnect

# Resume this Claude session
cd /Users/papillonm5/Documents/Projects/wifi-disconnect && claude --resume hotspot-lid-disconnect
```
