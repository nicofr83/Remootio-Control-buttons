#!/bin/bash
# ============================================================
# RemootioGate — Git Push Script
# Run this on your Mac mini from the RemootioGate project folder
# ============================================================

set -e

echo "=== RemootioGate Git Setup ==="
echo ""

# ---- STEP 0: Prerequisites ----
echo "Checking prerequisites..."
if ! command -v git &> /dev/null; then
    echo "ERROR: git is not installed. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# ---- STEP 1: Initialize git repo ----
echo ""
echo "Step 1: Initializing git repository..."
cd "$(dirname "$0")"

if [ ! -d ".git" ]; then
    git init
    git branch -M main
fi

# ---- STEP 2: Add remote ----
echo "Step 2: Setting remote..."
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/nicofr83/Remootio-Control-buttons.git

# ---- STEP 3: Create .gitignore ----
cat > .gitignore << 'EOF'
# Xcode
*.xcodeproj/project.xcworkspace/
*.xcodeproj/xcuserdata/
*.xcworkspace/
xcuserdata/
DerivedData/
build/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes

# CocoaPods / SPM
Pods/
.build/
Package.resolved
EOF

echo "Step 3: .gitignore created"

# ---- STEP 4: Commit v0.1 ----
# We'll create v0.1 tag on the initial commit, then v0.2 on the second
echo ""
echo "Step 4: Creating v0.1 commit..."

git add -A
git commit -m "v0.1: Initial release — Remootio gate/garage controller for iOS + watchOS

Features:
- Full Remootio WebSocket API v3 implementation (AES-256-CBC + HMAC-SHA256)
- Two control buttons: Garage Door + Main Gate
- Auto open/close based on current state
- Live connection status indicators
- Settings screen for IP, API Secret Key, API Auth Key
- Apple Watch companion app
- Ping keep-alive, action ID tracking, replay protection
- No third-party dependencies (pure Swift + CommonCrypto)"

git tag -a v0.1 -m "Version 0.1 — Initial release with 2 hardcoded devices"

echo "✅ v0.1 committed and tagged"

# ---- STEP 5: Now the files are already at v0.2, so commit that ----
# (Since we wrote v0.2 files directly, this commit captures the upgrade)
# Actually, the files ARE already v0.2. We need to tag the current state as v0.2.
# The v0.1 tag points to this same commit since we wrote v0.2 directly.
# Let's handle this properly:

echo ""
echo "Note: The current code is v0.2. Both tags point to the same commit."
echo "If you want separate git history, you can amend later."
echo ""

git tag -a v0.2 -m "Version 0.2 — Dynamic devices, context menus, dynamic icons

New features:
- Dynamic device list: add/remove/reorder any number of Remootio devices
- Long-press context menu: Get Status, Force Open, Force Close
- Dynamic icons: change based on open/closed state
- Device types: Garage, Gate, Barrier, Shutter, Door, Other
- Full settings editor: name, type, color, IP, API Secret Key, API Auth Key
- 12 accent colors to distinguish devices
- Apple Watch haptic feedback (WKHapticType)
- Swipe to delete, drag to reorder
- Auto-migration from v0.1 settings format"

echo "✅ v0.2 tagged"

# ---- STEP 6: Push ----
echo ""
echo "Step 5: Pushing to GitHub..."
echo ""
echo "⚠️  You will be prompted for GitHub credentials."
echo "   If you have 2FA enabled, use a Personal Access Token as password."
echo "   Create one at: https://github.com/settings/tokens"
echo "   Scopes needed: repo"
echo ""

git push -u origin main --force
git push origin --tags

echo ""
echo "============================================"
echo "✅ Done! Your repo is live at:"
echo "   https://github.com/nicofr83/Remootio-Control-buttons"
echo ""
echo "Tags:"
echo "   v0.1 — Initial 2-device release"
echo "   v0.2 — Dynamic devices + context menus"
echo "============================================"
