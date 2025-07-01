#!/bin/bash

# Nachna Go Server Startup Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Nachna Go Server Startup ==="
echo "Working directory: $(pwd)"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed or not in PATH"
    exit 1
fi

echo "✅ Go version: $(go version)"

# Build the server
echo "🔨 Building server..."
if go build -o nachna-server .; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

# Check if port 8008 is already in use
if command -v lsof &> /dev/null; then
    if lsof -Pi :8008 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port 8008 is already in use. Stopping existing process..."
        pkill -f nachna-server || true
        sleep 2
    fi
fi

# Start the server
echo "🚀 Starting server on port 8008..."
exec ./nachna-server