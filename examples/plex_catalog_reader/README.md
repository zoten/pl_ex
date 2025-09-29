# Plex Catalog Reader

A complete example application demonstrating how to use PlEx to read all titles from a Plex Media Server using environment variables.

## Features

- 🔐 **Environment Variable Configuration** - Secure token management
- 🌐 **IP Address Connection** - Connect to any Plex server by IP
- 📚 **Complete Catalog Reading** - Lists all titles from all library sections
- 🎬 **Multiple Media Types** - Movies, TV shows, music, photos, etc.
- ✅ **Connection Testing** - Validates server connectivity before reading

## Quick Start

### 1. Set Environment Variables

```bash
# Required: Your Plex authentication token
export PLEX_TOKEN="your-plex-token-here"

# Required: Your Plex server URL (replace with your server's IP)
export PLEX_SERVER_URL="http://192.168.1.100:32400"

# Optional: Client identifier (defaults to "plex-catalog-reader")
export PLEX_CLIENT_ID="my-catalog-reader"
```

### 2. Install Dependencies

```bash
cd examples/plex_catalog_reader
mix deps.get
```

### 3. Run the Application

```bash
# Method 1: Direct execution
mix run -e "PlexCatalogReader.run()"

# Method 2: Interactive mode
iex -S mix
iex> PlexCatalogReader.run()
```

## Getting Your Plex Token

You need a Plex authentication token to access your server:

1. **From Plex Web App:**
   - Open Plex Web App in your browser
   - Go to Settings → Account → Privacy
   - Click "Show Advanced"
   - Copy the "X-Plex-Token" value

2. **From URL:**
   - Visit: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/

## Finding Your Plex Server IP

1. **Local Network:**
   - Check your router's admin panel for connected devices
   - Look for "Plex Media Server" or your server's hostname
   - Common IPs: `192.168.1.x`, `192.168.0.x`, `10.0.0.x`

2. **From Plex Web App:**
   - Go to Settings → Server → Network
   - Note the "LAN Networks" IP address

3. **Default Port:**
   - Plex typically runs on port `32400`
   - Full URL format: `http://YOUR_SERVER_IP:32400`

## Example Output

```
📚 Plex Catalog Reader
======================
✅ Connected to http://192.168.1.100:32400

📁 Found 4 library sections:

📂 Movies (movie)
   127 items:
   • The Matrix (1999)
   • Inception (2010)
   • Interstellar (2014)
   • The Dark Knight (2008)
   • Pulp Fiction (1994)
   ... and 122 more

📂 TV Shows (show)
   45 items:
   • Breaking Bad (2008)
   • Game of Thrones (2011)
   • The Office (2005)
   • Friends (1994)
   • Stranger Things (2016)
   ... and 40 more

📂 Music (artist)
   23 items:
   • The Beatles
   • Pink Floyd
   • Led Zeppelin
   • Queen
   • The Rolling Stones
   ... and 18 more

📂 Photos (photo)
   156 items:
   • Family Vacation 2023
   • Wedding Photos
   • Birthday Party
   • Christmas 2022
   • Summer Trip
   ... and 151 more

🎉 Catalog reading complete!
```

## Configuration Options

The application supports these environment variables:

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `PLEX_TOKEN` | ✅ | Your Plex authentication token | `abc123def456` |
| `PLEX_SERVER_URL` | ✅ | Your Plex server URL | `http://192.168.1.100:32400` |
| `PLEX_CLIENT_ID` | ❌ | Client identifier | `my-catalog-reader` |

## Troubleshooting

### Connection Issues

**Problem:** `Connection failed: :connection_refused`
- **Solution:** Check if your Plex server is running and accessible
- **Check:** Can you access the Plex Web UI at the same URL?

**Problem:** `Connection failed: :unauthorized`
- **Solution:** Verify your `PLEX_TOKEN` is correct and valid
- **Check:** Try getting a fresh token from Plex Web App

**Problem:** `Connection failed: :timeout`
- **Solution:** Check if the IP address and port are correct
- **Check:** Try pinging the server: `ping 192.168.1.100`

### Network Issues

**Problem:** Can't find server IP
- **Solution:** Check your router's DHCP client list
- **Alternative:** Use Plex's server discovery in the web app

**Problem:** Server not accessible from other machines
- **Solution:** Check Plex server's network settings
- **Check:** Ensure "Enable local network discovery" is enabled

## Code Structure

```
plex_catalog_reader/
├── lib/
│   ├── plex_catalog_reader.ex          # Main application logic
│   └── plex_catalog_reader/
│       └── application.ex              # OTP application
├── mix.exs                             # Project configuration
└── README.md                           # This file
```

## Extending the Application

This example can be extended to:

- Export catalog data to JSON/CSV files
- Filter content by genre, year, or rating
- Generate reports and statistics
- Sync with external databases
- Create web dashboards
- Monitor library changes

## Dependencies

- **PlEx** - Plex Media Server API client
- **Finch** - HTTP client for network requests
- **Jason** - JSON encoding/decoding

## License

This example application is provided as-is for educational purposes.
