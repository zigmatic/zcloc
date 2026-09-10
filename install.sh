#!/bin/sh
# zcloc install script
# Builds and installs zcloc to ~/.local/bin (or a prefix of your choice)
#
# Usage:
#   ./install.sh              # installs to ~/.local/bin
#   ./install.sh /usr/local   # installs to /usr/local/bin
#   PREFIX=/opt ./install.sh  # installs to /opt/bin

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PREFIX="${1:-${PREFIX:-$HOME/.local}}"
BINDIR="$PREFIX/bin"

# --- detect architecture and OS ---
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
    x86_64|amd64) ZIG_ARCH="x86_64" ;;
    aarch64|arm64) ZIG_ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    linux) ZIG_OS="linux" ;;
    darwin) ZIG_OS="macos" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

ZIG_VERSION="0.16.0"
ZIG_TARGET="zig-${ZIG_ARCH}-${ZIG_OS}-${ZIG_VERSION}"
ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TARGET}.tar.xz"

# --- check for existing zig or download it ---
ZIG_BIN=""
if command -v zig >/dev/null 2>&1; then
    ZIG_VER_OUTPUT=$(zig version 2>/dev/null || echo "unknown")
    if [ "$ZIG_VER_OUTPUT" = "$ZIG_VERSION" ]; then
        ZIG_BIN="zig"
    fi
fi

if [ -z "$ZIG_BIN" ]; then
    ZIG_DIR="$SCRIPT_DIR/.zig-bootstrap"
    if [ ! -d "$ZIG_DIR" ]; then
        echo "Downloading Zig $ZIG_VERSION for $ZIG_OS/$ZIG_ARCH..."
        if command -v curl >/dev/null 2>&1; then
            curl -sL "$ZIG_URL" -o /tmp/"$ZIG_TARGET".tar.xz
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$ZIG_URL" -O /tmp/"$ZIG_TARGET".tar.xz
        else
            echo "Error: need curl or wget to download Zig."
            exit 1
        fi
        echo "Extracting..."
        tar xf /tmp/"$ZIG_TARGET".tar.xz -C "$SCRIPT_DIR"
        mv "$SCRIPT_DIR/$ZIG_TARGET" "$ZIG_DIR"
        rm -f /tmp/"$ZIG_TARGET".tar.xz
    fi
    ZIG_BIN="$ZIG_DIR/zig"
fi

# --- build ---
echo "Building zcloc with $ZIG_BIN..."
cd "$SCRIPT_DIR"
"$ZIG_BIN" build -Doptimize=ReleaseFast

if [ ! -f "$SCRIPT_DIR/zig-out/bin/zcloc" ]; then
    echo "Build failed: binary not found at zig-out/bin/zcloc"
    exit 1
fi

# --- install ---
mkdir -p "$BINDIR"
cp "$SCRIPT_DIR/zig-out/bin/zcloc" "$BINDIR/zcloc"
chmod +x "$BINDIR/zcloc"

# --- cleanup build artifacts ---
rm -rf "$SCRIPT_DIR/.zig-cache" "$SCRIPT_DIR/zig-out"

echo ""
echo "Installed zcloc to $BINDIR/zcloc"

# --- check PATH ---
case ":$PATH:" in
    *":$BINDIR:"*) ;;
    *) echo "Note: $BINDIR is not in your PATH."
       echo "Add this to your shell profile:"
       echo "  export PATH=\"$BINDIR:\$PATH\""
       ;;
esac

echo ""
echo "Run 'zcloc --help' to get started."
