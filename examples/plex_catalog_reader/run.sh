#!/bin/bash

# Plex Catalog Reader - Quick Start Script
# 
# This script helps you set up and run the Plex Catalog Reader example.

set -e

echo "🎬 Plex Catalog Reader Setup"
echo "============================"

# Check if environment variables are set
if [ -z "$PLEX_TOKEN" ]; then
    echo ""
    echo "❌ PLEX_TOKEN environment variable is not set."
    echo ""
    echo "To get your Plex token:"
    echo "1. Open Plex Web App in your browser"
    echo "2. Go to Settings → Account → Privacy"
    echo "3. Click 'Show Advanced'"
    echo "4. Copy the 'X-Plex-Token' value"
    echo ""
    echo "Then set it like this:"
    echo "export PLEX_TOKEN=\"your-token-here\""
    echo ""
    exit 1
fi

if [ -z "$PLEX_SERVER_URL" ]; then
    echo ""
    echo "❌ PLEX_SERVER_URL environment variable is not set."
    echo ""
    echo "Set your Plex server URL like this:"
    echo "export PLEX_SERVER_URL=\"http://192.168.1.100:32400\""
    echo ""
    echo "Replace 192.168.1.100 with your Plex server's IP address."
    echo ""
    exit 1
fi

echo "✅ Environment variables are set:"
echo "   PLEX_TOKEN: [REDACTED]"
echo "   PLEX_SERVER_URL: $PLEX_SERVER_URL"
echo "   PLEX_CLIENT_ID: ${PLEX_CLIENT_ID:-plex-catalog-reader}"

echo ""
echo "📦 Installing dependencies..."
mix deps.get

echo ""
echo "🚀 Running Plex Catalog Reader..."
echo ""

mix run -e "PlexCatalogReader.run()"
