# 🚀 Streaming API Testing Guide

This guide provides comprehensive instructions for testing the Nachna streaming APIs using multiple approaches.

## 📋 Overview

The streaming APIs provide real-time updates during workshop processing operations using Server-Sent Events (SSE):

- **POST** `/api/streaming/refresh-workshops` - Refresh workshops with real-time progress
- **GET** `/api/streaming/process-studio?studio_id={id}` - Process specific studio with real-time updates

## 🛠️ Server Setup (Required First)

Before testing, you need to start the streaming server:

### Option 1: Local Go Server
```bash
# Navigate to server directory
cd server

# Install dependencies (if needed)
go mod tidy

# Start the server
go run main.go

# Or build and run
go build -o dance_server
./dance_server --dev
```

### Option 2: Docker (if available)
```bash
# Start the server container
docker-compose up server
```

### Option 3: Production Server
If you have access to the production server at `40.192.39.104:8008`, you can test against it directly.

## 🎯 Testing Approaches

### 1. 🐍 Python Test Suite (Recommended)

**File:** `test_streaming_apis.py`

**Features:**
- Comprehensive automated testing
- Event validation and statistics
- Performance testing
- Error handling validation
- Generates cURL commands and web client code

**Usage:**
```bash
# Install required dependencies
pip install requests sseclient-py urllib3

# Run all tests (uses localhost:8008 by default)
python test_streaming_apis.py

# Run with custom configuration
python test_streaming_apis.py http://localhost:8008 dance_n_addiction
python test_streaming_apis.py http://40.192.39.104:8008 dance_n_addiction
```

**What it tests:**
- ✅ Connection establishment
- ✅ Event streaming (logs, progress, completion)
- ✅ Error handling scenarios
- ✅ Performance characteristics
- ✅ Response time validation

### 2. 🌐 Web Test Client (Interactive)

**File:** `test_streaming_web_client.html`

**Features:**
- Beautiful, responsive UI
- Real-time event display
- Progress bar visualization
- Statistics tracking
- Interactive testing

**Usage:**
1. Start your server (see Server Setup above)
2. Open `test_streaming_web_client.html` in your browser
3. Click test buttons to start streaming
4. Watch real-time events and progress
5. View statistics and connection status

**What you can test:**
- ✅ Visual progress tracking
- ✅ Real-time event monitoring
- ✅ Error scenario testing
- ✅ Connection status indicators

### 3. 🔧 Quick Shell Script (Local)

**File:** `test_streaming_local.sh`

**Features:**
- Fast command-line testing
- Colored output
- Timeout-based validation
- Basic error handling
- Server connectivity check

**Usage:**
```bash
# Make executable (if needed)
chmod +x test_streaming_local.sh

# Run with defaults (localhost:8008)
./test_streaming_local.sh

# Run with custom server
./test_streaming_local.sh http://localhost:8080
./test_streaming_local.sh http://40.192.39.104:8008 dance_n_addiction
```

**What it tests:**
- ✅ Server connectivity
- ✅ Basic connectivity
- ✅ Endpoint availability
- ✅ Error responses
- ✅ Timeout handling

### 4. 🔧 Quick Shell Script (Production)

**File:** `test_streaming_quick.sh`

**Features:**
- Tests against production server
- Fast command-line testing
- Colored output

**Usage:**
```bash
# Make executable (if needed)
chmod +x test_streaming_quick.sh

# Run quick tests against production
./test_streaming_quick.sh
```

### 5. 📡 Manual cURL Testing

**Direct cURL commands for manual testing:**

#### Test Process Studio Streaming (Local):
```bash
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "http://localhost:8008/api/streaming/process-studio?studio_id=dance_n_addiction"
```

#### Test Refresh Workshops Streaming (Local):
```bash
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"studio_id":"dance_n_addiction"}' \
     "http://localhost:8008/api/streaming/refresh-workshops"
```

#### Test Process Studio Streaming (Production):
```bash
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "http://40.192.39.104:8008/api/streaming/process-studio?studio_id=dance_n_addiction"
```

#### Test Refresh Workshops Streaming (Production):
```bash
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"studio_id":"dance_n_addiction"}' \
     "http://40.192.39.104:8008/api/streaming/refresh-workshops"
```

#### Test Error Handling:
```bash
# Invalid studio ID
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "http://localhost:8008/api/streaming/process-studio?studio_id=invalid_studio"

# Missing studio ID
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "http://localhost:8008/api/streaming/process-studio"
```

## 📊 Expected Event Types

### Log Events (`event: logs`)
```json
{
  "type": "logs",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "message": "Processing link 5 of 10",
    "level": "info"
  }
}
```

**Log Levels:**
- `info` - General information
- `success` - Successful operations
- `warning` - Warning messages
- `error` - Error messages

### Progress Events (`event: progress_bar`)
```json
{
  "type": "progress_bar",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "percentage": 50.0,
    "current": 5,
    "total": 10,
    "message": "Processing link 5 of 10"
  }
}
```

### Special Events
- `event: complete` - Process completion
- `event: error` - Error messages
- `event: close` - Connection closure

## 🧪 Testing Scenarios

### 1. Happy Path Testing
- ✅ Normal operation with valid studio ID
- ✅ Complete event stream from start to finish
- ✅ Progress updates at regular intervals
- ✅ Proper completion event

### 2. Error Handling Testing
- ✅ Invalid studio ID
- ✅ Missing studio ID parameter
- ✅ Network disconnection
- ✅ Server errors
- ✅ Timeout scenarios

### 3. Performance Testing
- ✅ Response time < 5 seconds
- ✅ Event rate > 0.5 events/second
- ✅ Connection stability
- ✅ Memory usage

### 4. Edge Case Testing
- ✅ Very long studio names
- ✅ Special characters in parameters
- ✅ Concurrent connections
- ✅ Rapid reconnections

## 🔍 Debugging Tips

### Common Issues:

1. **Server Not Running**
   - Start the Go server: `cd server && go run main.go`
   - Check if port 8008 is available
   - Verify server logs for errors

2. **No Events Received**
   - Check server is running on correct port
   - Verify CORS headers are set
   - Check network connectivity

3. **Connection Timeout**
   - Increase timeout values
   - Check server load
   - Verify firewall settings

4. **Invalid JSON in Events**
   - Check server-side JSON serialization
   - Verify event data structure
   - Look for encoding issues

5. **CORS Errors (Web Client)**
   - Ensure server allows cross-origin requests
   - Check browser console for errors
   - Verify server CORS configuration

### Debug Commands:

```bash
# Check server status (local)
curl -I "http://localhost:8008/api/streaming/process-studio?studio_id=dance_n_addiction"

# Check server status (production)
curl -I "http://40.192.39.104:8008/api/streaming/process-studio?studio_id=dance_n_addiction"

# Test with verbose output
curl -v -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "http://localhost:8008/api/streaming/process-studio?studio_id=dance_n_addiction"

# Check server logs
# (Check your server console/logs for detailed information)
```

## 📈 Performance Benchmarks

### Expected Performance:
- **Response Time:** < 5 seconds for first event
- **Event Rate:** > 0.5 events/second during processing
- **Connection Stability:** 100% uptime during test duration
- **Memory Usage:** < 100MB for typical session

### Load Testing:
```bash
# Test multiple concurrent connections (local)
for i in {1..5}; do
  curl -N -H "Accept: text/event-stream" \
       -H "Cache-Control: no-cache" \
       -X GET \
       "http://localhost:8008/api/streaming/process-studio?studio_id=dance_n_addiction" &
done
wait
```

## 🎯 Test Results Interpretation

### Success Criteria:
- ✅ Connection established within 5 seconds
- ✅ Receives log events with proper levels
- ✅ Receives progress events with valid percentages
- ✅ Receives completion event
- ✅ Proper error handling for invalid inputs
- ✅ Graceful connection closure

### Failure Indicators:
- ❌ Connection timeout (> 10 seconds)
- ❌ No events received
- ❌ Invalid JSON in events
- ❌ Missing completion event
- ❌ Improper error responses
- ❌ Connection drops unexpectedly

## 🚀 Quick Start Guide

### For Local Testing:
1. **Start Server:** `cd server && go run main.go`
2. **Quick Test:** `./test_streaming_local.sh`
3. **Interactive Test:** Open `test_streaming_web_client.html`
4. **Comprehensive Test:** `python test_streaming_apis.py`

### For Production Testing:
1. **Quick Test:** `./test_streaming_quick.sh`
2. **Interactive Test:** Open `test_streaming_web_client.html` (change URL to production)
3. **Manual Test:** Use cURL commands with production URL

## 🚀 Next Steps

1. **Start with Server Setup:** Ensure your server is running
2. **Quick Test:** Run `./test_streaming_local.sh` or `./test_streaming_quick.sh`
3. **Interactive Testing:** Open `test_streaming_web_client.html`
4. **Comprehensive Testing:** Run `python test_streaming_apis.py`
5. **Manual Verification:** Use cURL commands for specific scenarios
6. **Performance Testing:** Monitor server logs and metrics

## 📞 Support

If you encounter issues:
1. **Check Server Status:** Ensure the server is running and accessible
2. **Check Server Logs:** Look for detailed error messages in server console
3. **Verify Network:** Test connectivity to the server
4. **Test with Different Studio IDs:** Try various studio configurations
5. **Check Browser Console:** Look for web client errors
6. **Review Implementation:** Check `server/api/streamingWorkshop.go`

## 🔧 Troubleshooting

### Server Won't Start:
```bash
# Check if port is in use
lsof -i :8008

# Kill process using port (if needed)
kill -9 $(lsof -t -i:8008)

# Check Go installation
go version

# Check dependencies
cd server && go mod tidy
```

### Tests Failing:
```bash
# Test basic connectivity
curl -I http://localhost:8008

# Check server logs
# Look for error messages in server console

# Test with different timeout
curl --connect-timeout 10 http://localhost:8008
```

---

**Happy Testing! 🎭** 