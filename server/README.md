# Nachna Go Server

A lightweight Go server for the Nachna application with health check functionality.

## Features

- ✅ Health check API endpoint
- ✅ CORS support
- ✅ Request logging middleware
- ✅ Graceful shutdown
- ✅ Comprehensive error handling
- ✅ JSON response formatting

## Requirements

- Go 1.24 or later
- Linux/macOS/Windows

## Quick Start

### Using the startup script (recommended):
```bash
./start_server.sh
```

### Manual build and run:
```bash
# Build the server
go build -o nachna-server .

# Run the server
./nachna-server
```

## API Endpoints

### Health Check
- **URL**: `GET /api/health_check`
- **Description**: Returns server health status
- **Response Format**:
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2025-07-01T08:49:26Z",
  "version": "1.0.0",
  "service": "nachna-server"
}
```

## Testing

Run the comprehensive test suite:
```bash
./test_health.sh
```

### Manual testing:
```bash
# Test health check
curl http://localhost:8008/api/health_check

# Test with formatted JSON
curl -s http://localhost:8008/api/health_check | python3 -m json.tool

# Test CORS
curl -X OPTIONS -v http://localhost:8008/api/health_check
```

## Configuration

### Server Configuration
- **Port**: 8008 (configured in `main.go`)
- **Read Timeout**: 15 seconds
- **Write Timeout**: 15 seconds
- **Idle Timeout**: 60 seconds

### CORS Configuration
- **Allowed Origins**: `*` (all origins)
- **Allowed Methods**: `GET, POST, PUT, DELETE, OPTIONS`
- **Allowed Headers**: `Content-Type, Authorization`

## Production Deployment

### Using systemd:
```bash
# Copy the service file
sudo cp nachna-go-server.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable the service
sudo systemctl enable nachna-go-server

# Start the service
sudo systemctl start nachna-go-server

# Check status
sudo systemctl status nachna-go-server
```

### Service Management:
```bash
# Start the service
sudo systemctl start nachna-go-server

# Stop the service
sudo systemctl stop nachna-go-server

# Restart the service
sudo systemctl restart nachna-go-server

# View logs
sudo journalctl -u nachna-go-server -f
```

## Development

### Project Structure
```
server/
├── main.go                    # Main server entry point
├── handler/
│   ├── init.go               # Router setup and middleware
│   └── health_check.go       # Health check handler
├── database/
│   └── database.go           # Database operations (placeholder)
├── go.mod                    # Go module definition
├── go.sum                    # Go module checksums
├── start_server.sh           # Startup script
├── test_health.sh            # Test script
├── nachna-go-server.service  # Systemd service file
└── README.md                 # This file
```

### Dependencies
- `github.com/gorilla/mux` - HTTP router
- `github.com/gorilla/handlers` - CORS and other HTTP handlers

### Building for Different Platforms
```bash
# Linux
GOOS=linux GOARCH=amd64 go build -o nachna-server-linux .

# Windows
GOOS=windows GOARCH=amd64 go build -o nachna-server-windows.exe .

# macOS
GOOS=darwin GOARCH=amd64 go build -o nachna-server-macos .
```

## Troubleshooting

### Server won't start
1. Check if port 8008 is already in use:
   ```bash
   lsof -i :8008  # or
   netstat -tlnp | grep :8008
   ```

2. Check server logs:
   ```bash
   # If running with systemd
   sudo journalctl -u nachna-go-server -f
   
   # If running manually
   cat server.log  # (if using nohup)
   ```

### Health check fails
1. Verify server is running:
   ```bash
   ps aux | grep nachna-server
   ```

2. Test local connectivity:
   ```bash
   curl -v http://localhost:8008/api/health_check
   ```

3. Check firewall settings (if needed):
   ```bash
   sudo ufw status
   ```

## Performance

- **Response Time**: Typical response time < 10ms
- **Memory Usage**: ~10-15MB baseline
- **CPU Usage**: Minimal under normal load
- **Concurrent Connections**: Supports thousands of concurrent connections

## Security

- CORS enabled for cross-origin requests
- No new privileges escalation
- Private temporary filesystem
- Protected system directories
- Request logging for audit trails

## Contributing

1. Make changes following the existing code style
2. Test your changes with `./test_health.sh`
3. Update documentation if needed
4. Ensure the server builds and runs correctly

## License

Part of the Nachna application suite.