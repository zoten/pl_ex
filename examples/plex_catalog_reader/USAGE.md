# Quick Usage Guide

## 🚀 Quick Start (3 steps)

### 1. Set Environment Variables
```bash
export PLEX_TOKEN="your-plex-token-here"
export PLEX_SERVER_URL="http://192.168.1.100:32400"  # Replace with your server IP
```

### 2. Test Connection (Optional but recommended)
```bash
elixir test_connection.exs
```

### 3. Run Catalog Reader
```bash
# Option A: Use the convenience script
./run.sh

# Option B: Run directly
mix run -e "PlexCatalogReader.run()"
```

## 📋 Example Commands

```bash
# Full setup and run
export PLEX_TOKEN="abc123def456"
export PLEX_SERVER_URL="http://192.168.1.50:32400"
./run.sh

# Test connection only
elixir test_connection.exs

# Interactive mode
iex -S mix
iex> PlexCatalogReader.run()
```

## 🔍 Finding Your Server IP

Common ways to find your Plex server IP:

1. **Router Admin Panel**: Look for "Plex Media Server" device
2. **Network Scanner**: Use `nmap -sn 192.168.1.0/24` 
3. **Plex Web App**: Settings → Server → Network
4. **Command Line**: `ping plex-server-name.local`

## 💡 Tips

- **Default Port**: Plex runs on port 32400
- **Local Server**: Use `http://localhost:32400` if running locally
- **Token Security**: Never commit your token to version control
- **Network Issues**: Ensure firewall allows port 32400

## 🐛 Common Issues

| Problem | Solution |
|---------|----------|
| "Connection refused" | Check if Plex server is running |
| "Unauthorized" | Verify your PLEX_TOKEN is correct |
| "Timeout" | Check IP address and network connectivity |
| "No sections found" | Server might be empty or have permission issues |
