#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/ClaudeTrafficLight.app"
BIN_DIR="$APP_DIR/Contents/MacOS"

mkdir -p "$BIN_DIR"

swiftc -o "$BIN_DIR/ClaudeTrafficLight" "$SCRIPT_DIR/main.swift" \
    -framework SwiftUI -framework AppKit

cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

echo "Build complete: $APP_DIR"
echo "Run with: open $APP_DIR"
