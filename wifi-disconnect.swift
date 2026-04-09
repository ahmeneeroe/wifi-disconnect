import Cocoa
import CoreWLAN

// MARK: - Configuration

let homeDir = NSHomeDirectory()
let configDir = "\(homeDir)/.config/wifi-disconnect"
let configFile = "\(configDir)/config.txt"
let logFile = "\(configDir)/disconnect.log"
let wifiInterface = "en0"

// iPhone hotspot always uses 172.20.10.0/28
let iPhoneHotspotPrefix = "172.20.10."

// Mutable state: tracks whether we turned WiFi off (so we can restore on wake)
var didDisableWiFi = false

/// Read hotspot SSID patterns from config file, one per line.
/// Lines starting with # are comments. Falls back to ["iPhone"].
func loadPatterns() -> [String] {
    guard let content = try? String(contentsOfFile: configFile, encoding: .utf8) else {
        return ["iPhone"]
    }
    let lines = content.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    return lines.isEmpty ? ["iPhone"] : lines
}

let patterns = loadPatterns()

// MARK: - Logging

func log(_ msg: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let ts = formatter.string(from: Date())
    let entry = "[\(ts)] \(msg)\n"
    if let handle = FileHandle(forWritingAtPath: logFile) {
        handle.seekToEndOfFile()
        if let data = entry.data(using: .utf8) { handle.write(data) }
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: logFile, contents: entry.data(using: .utf8))
    }
}

// MARK: - Network helpers

/// Get the IPv4 address of the WiFi interface via ifconfig.
func getIPAddress() -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
    proc.arguments = [wifiInterface]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do { try proc.run() } catch { return nil }
    proc.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    for line in output.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("inet ") {
            let parts = trimmed.split(separator: " ")
            if parts.count >= 2 { return String(parts[1]) }
        }
    }
    return nil
}

/// Get current SSID via networksetup (may return nil due to Location Services).
func getCurrentSSID() -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    proc.arguments = ["-getairportnetwork", wifiInterface]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do { try proc.run() } catch { return nil }
    proc.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return nil }
    let prefix = "Current Wi-Fi Network: "
    guard output.hasPrefix(prefix) else { return nil }
    let ssid = output.replacingOccurrences(of: prefix, with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return ssid.isEmpty ? nil : ssid
}

/// Detect if the current WiFi connection is an iPhone hotspot.
/// Uses two methods:
///   1. IP subnet (172.20.10.0/28) — always works, no permissions needed
///   2. SSID pattern matching — works if Location Services is available
func isIPhoneHotspot() -> (detected: Bool, reason: String) {
    // Method 1: Check IP range (most reliable, no permissions needed)
    if let ip = getIPAddress(), ip.hasPrefix(iPhoneHotspotPrefix) {
        return (true, "IP \(ip) in iPhone hotspot range")
    }
    // Method 2: Check SSID if available
    if let ssid = getCurrentSSID() {
        if let matched = patterns.first(where: { ssid.localizedCaseInsensitiveContains($0) }) {
            return (true, "SSID '\(ssid)' matched pattern '\(matched)'")
        }
        return (false, "SSID '\(ssid)' — no pattern match")
    }
    return (false, "no hotspot detected")
}

// MARK: - WiFi actions

/// Disconnect from current WiFi network.
func disconnectWiFi() {
    // Try CoreWLAN disassociate first (clean disconnect, WiFi stays on)
    if let iface = CWWiFiClient.shared().interface() {
        iface.disassociate()
        log("Disassociated via CoreWLAN")
        return
    }
    // Fallback: turn WiFi off entirely
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    proc.arguments = ["-setairportpower", wifiInterface, "off"]
    do { try proc.run() } catch { return }
    proc.waitUntilExit()
    didDisableWiFi = true
    log("Turned WiFi off (fallback)")
}

/// Turn WiFi back on.
func enableWiFi() {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    proc.arguments = ["-setairportpower", wifiInterface, "on"]
    do { try proc.run() } catch { return }
    proc.waitUntilExit()
}

// MARK: - Sleep / Wake observers

let nc = NSWorkspace.shared.notificationCenter

nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
    let (detected, reason) = isIPhoneHotspot()
    if detected {
        disconnectWiFi()
        log("Sleep: disconnected — \(reason)")
    } else {
        log("Sleep: no action — \(reason)")
    }
}

nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
    if didDisableWiFi {
        enableWiFi()
        didDisableWiFi = false
        log("Wake: re-enabled WiFi")
    } else {
        log("Wake: no action needed")
    }
}

// MARK: - Start

log("Started — IP detection (172.20.10.x) + SSID patterns: \(patterns.joined(separator: ", "))")
RunLoop.current.run()
