# 🎭 Nachna Streaming API Testing

Quick guide to test the real-time streaming APIs for workshop processing.

## 🚀 Quick Start

### 1. Start the Server
```bash
# Navigate to server directory and start
cd server && go run main.go
```

### 2. Test the APIs

**Option A: Quick Test (Recommended)**
```bash
./test_streaming_local.sh
```

**Option B: Interactive Web Client**
```bash
# Open in browser
open test_streaming_web_client.html
```

**Option C: Comprehensive Python Test**
```bash
pip install requests sseclient-py urllib3
python test_streaming_apis.py
```

**Option D: Manual cURL**
```bash
# Test process studio
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "http://localhost:8008/api/streaming/process-studio?studio_id=dance_n_addiction"

# Test refresh workshops
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"studio_id":"dance_n_addiction"}' \
     "http://localhost:8008/api/streaming/refresh-workshops"
```

## 📡 API Endpoints

- **GET** `/api/streaming/process-studio?studio_id={id}` - Process specific studio
- **POST** `/api/streaming/refresh-workshops` - Refresh workshops with progress

## 📊 Expected Events

- `logs` - Text messages with levels (info, success, warning, error)
- `progress_bar` - Progress updates with percentage and counts
- `complete` - Process completion
- `error` - Error messages

## 🔧 Troubleshooting

**Server not starting?**
```bash
# Check if port is in use
lsof -i :8008

# Kill process if needed
kill -9 $(lsof -t -i:8008)

# Check Go installation
go version
```

**Tests failing?**
```bash
# Test basic connectivity
curl -I http://localhost:8008

# Check server logs in terminal
```

## 📚 Detailed Documentation

For comprehensive testing instructions, see:
- `STREAMING_API_TESTING_GUIDE.md` - Complete testing guide
- `test_streaming_apis.py` - Python test suite with documentation
- `test_streaming_web_client.html` - Interactive web client

## 🎯 Test Files

- `test_streaming_local.sh` - Local server testing
- `test_streaming_quick.sh` - Production server testing  
- `test_streaming_apis.py` - Comprehensive Python tests
- `test_streaming_web_client.html` - Interactive web client

---

**Happy Testing! 🎭** 