# RemootioGate — iOS + Apple Watch Controller

A native Swift app to control **any number** of Remootio devices (garage doors, gates, barriers, shutters, doors) from your iPhone and Apple Watch.

## Features

### v0.2 (current)
- **Dynamic device list** — add as many Remootio devices as you want (not limited to 2)
- **Long-press context menu** with haptic feedback:
  - 📊 **Get Status** — queries open/closed state
  - 🔓 **Force Open** — sends OPEN regardless of current state
  - 🔒 **Force Close** — sends CLOSE regardless of current state
- **Dynamic icons** that change based on open/closed state (e.g., `door.garage.open` ↔ `door.garage.closed`)
- **Device types**: Garage Door, Gate, Barrier, Shutter, Door, Other — each with its own icon set
- **Full settings editor** — name, type, color, IP address, API Secret Key, API Auth Key all configurable per device
- **Color picker** — 12 accent colors to visually distinguish your devices
- **Apple Watch optimized** — bold icons, high-contrast status, haptic feedback (`WKHapticType`)
- **Swipe to delete**, drag to reorder devices
- **Auto-migration** from v0.1 settings format

### v0.1
- Two hardcoded buttons (Garage Door + Main Gate)
- Basic open/close toggle
- Full Remootio API v3 protocol

## Architecture

```
RemootioGate/
├── Shared/                      ← Code shared between iOS and watchOS
│   ├── RemootioClient.swift     ← Full Remootio WebSocket API v3 client
│   │                              (AES-256-CBC, HMAC-SHA256, session management)
│   ├── DeviceConfig.swift       ← Dynamic device model, types, colors, persistence
│   └── DeviceController.swift   ← ViewModel: N-device management, actions
├── RemootioGate/                ← iOS app
│   ├── RemootioGateApp.swift
│   └── Views/
│       ├── ContentView.swift    ← Dynamic device list + context menus
│       └── SettingsView.swift   ← Full device editor (add/edit/delete/reorder)
├── RemootioGateWatch/           ← watchOS app
│   ├── RemootioGateWatchApp.swift
│   └── Views/
│       └── WatchContentView.swift  ← Watch-optimized buttons + haptics
└── README.md
```

## Prerequisites

1. **Mac with Xcode 15+**
2. **iPhone** running iOS 17+
3. **Apple Watch** running watchOS 10+ (optional)
4. **Remootio devices** with WebSocket API enabled

### Apple Developer Account

**You do NOT need a paid account ($99/year) for personal use.**

With a free Apple ID:
- ✅ Build and run on your own iPhone/Watch via USB
- ✅ Apps work for 7 days, then just re-run from Xcode
- ❌ Cannot publish to the App Store

## Installation

### Step 1: Prepare Remootio devices

For each device, in the **Remootio app**:
1. Select device → Device Software → Remootio Websocket API
2. Enable the API
3. Note: **IP Address**, **API Secret Key** (64 hex chars), **API Auth Key** (64 hex chars)

### Step 2: Create the Xcode project (recommended)

Since `.pbxproj` files are fragile, create the project fresh:

1. **Xcode → File → New → Project → iOS → App**
   - Product Name: `RemootioGate`, Interface: SwiftUI, Language: Swift
2. Delete the auto-generated `ContentView.swift`
3. **Add Shared files** (right-click → Add Files):
   - Add `RemootioClient.swift`, `DeviceConfig.swift`, `DeviceController.swift` from `Shared/`
   - Check ✅ "Copy items if needed"
4. **Add iOS views**: drag `ContentView.swift` and `SettingsView.swift` into a `Views` group
5. **Replace** `RemootioGateApp.swift` with the one from the repo
6. **Add watchOS target**: File → New → Target → watchOS → App
   - Name: `RemootioGateWatch`
7. **Add Shared files to watch target**: select each Shared file → File Inspector → check ✅ `RemootioGateWatch`
8. Replace watch files with `RemootioGateWatchApp.swift` and `WatchContentView.swift`
9. **Add Info.plist key**: `NSLocalNetworkUsageDescription` = "RemootioGate needs local network access to communicate with your Remootio devices."

### Step 3: Configure signing

1. Select project → each target → Signing & Capabilities
2. Check "Automatically manage signing"
3. Select your Apple ID as Team
4. Change bundle ID if needed (e.g., `com.yourname.remootiogate`)

### Step 4: Build and run

1. Connect iPhone via USB
2. Enable Developer Mode: Settings → Privacy & Security → Developer Mode
3. Select your iPhone, press ▶ Run
4. Trust the developer profile on first launch: Settings → General → VPN & Device Management

### Step 5: Configure devices in the app

1. Tap ⚙️ gear icon → Add device (+ button)
2. Fill in: Name, Type, IP, API Secret Key, API Auth Key
3. Save → device appears on the main screen
4. Repeat for all your Remootio devices

## Usage

### Quick tap
Taps the button → auto-detects state → sends Open if closed, Close if open, Trigger if no sensor.

### Long press (context menu)
Long-press any device button to see:
- **Get Status** — refreshes the open/closed state
- **Force Open** — sends OPEN command regardless of current state
- **Force Close** — sends CLOSE command regardless of current state

### Apple Watch
Same two interactions work on the Watch with haptic feedback.

## Device Types & Icons

| Type    | Closed Icon                | Open Icon                  | Default Color |
|---------|---------------------------|---------------------------|---------------|
| Garage  | `door.garage.closed`      | `door.garage.open`        | Blue          |
| Gate    | `door.french.closed`      | `door.french.open`        | Orange        |
| Barrier | `xmark.rectangle.fill`    | `checkmark.rectangle.fill`| Purple        |
| Shutter | `blinds.horizontal.closed`| `blinds.horizontal.open`  | Teal          |
| Door    | `door.left.hand.closed`   | `door.left.hand.open`     | Indigo        |
| Other   | `lock.fill`               | `lock.open.fill`          | Gray          |

## Troubleshooting

**"Disconnected"**: Same Wi-Fi network? Correct IP? API enabled in Remootio app?

**"MAC verification failed"**: Double-check both 64-char hex keys are correct.

**App expires after 7 days**: Re-run from Xcode.

**Watch not connecting**: Watch needs Wi-Fi access to the same network as Remootio devices.

## Network

The Remootio API runs on your **local LAN** (port 8080). No internet required. All devices must be on the same Wi-Fi network.

## License

MIT — for personal use. Remootio API docs: https://github.com/remootio/remootio-api-documentation
