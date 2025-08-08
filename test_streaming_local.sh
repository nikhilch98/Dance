#!/bin/bash

# Local Streaming API Test Script
# Tests the streaming endpoints with configurable server URL

# Default configuration - change these as needed
DEFAULT_BASE_URL="http://localhost:8008"
DEFAULT_STUDIO_ID="dance_n_addiction"

# Allow command line overrides
BASE_URL="${1:-$DEFAULT_BASE_URL}"
STUDIO_ID="${2:-$DEFAULT_STUDIO_ID}"

echo "🚀 Local Streaming API Test"
echo "=========================="
echo "Base URL: $BASE_URL"
echo "Studio ID: $STUDIO_ID"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to test server connectivity
test_connectivity() {
    print_status "info" "Testing server connectivity..."
    
    # Try to connect to the server
    if curl -s --connect-timeout 5 "$BASE_URL" > /dev/null 2>&1; then
        print_status "success" "Server is accessible"
        return 0
    else
        print_status "error" "Cannot connect to server at $BASE_URL"
        print_status "warning" "Make sure the server is running and accessible"
        return 1
    fi
}

# Test server connectivity first
if ! test_connectivity; then
    echo ""
    print_status "info" "Server Setup Instructions:"
    echo "1. Start your Go server:"
    echo "   cd server && go run main.go"
    echo ""
    echo "2. Or if using Docker:"
    echo "   docker-compose up server"
    echo ""
    echo "3. Verify the server is running on the correct port"
    echo ""
    print_status "info" "You can also test with a different server URL:"
    echo "   ./test_streaming_local.sh http://your-server:port studio_id"
    exit 1
fi

# Test 1: Process Studio Streaming (GET)
echo "📡 Testing Process Studio Streaming..."
print_status "info" "Endpoint: GET $BASE_URL/api/streaming/process-studio?studio_id=$STUDIO_ID"

# Run the test for 5 seconds
timeout 5s curl -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    -X GET \
    "$BASE_URL/api/streaming/process-studio?studio_id=$STUDIO_ID" 2>/dev/null

if [ $? -eq 124 ]; then
    print_status "success" "Process Studio test completed (timeout after 5s)"
elif [ $? -eq 0 ]; then
    print_status "success" "Process Studio test completed (stream ended)"
else
    print_status "error" "Process Studio test failed (exit code: $?)"
fi

echo ""

# Test 2: Refresh Workshops Streaming (POST)
echo "📡 Testing Refresh Workshops Streaming..."
print_status "info" "Endpoint: POST $BASE_URL/api/streaming/refresh-workshops"

# Run the test for 5 seconds
timeout 5s curl -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "{\"studio_id\":\"$STUDIO_ID\"}" \
    "$BASE_URL/api/streaming/refresh-workshops" 2>/dev/null

if [ $? -eq 124 ]; then
    print_status "success" "Refresh Workshops test completed (timeout after 5s)"
elif [ $? -eq 0 ]; then
    print_status "success" "Refresh Workshops test completed (stream ended)"
else
    print_status "error" "Refresh Workshops test failed (exit code: $?)"
fi

echo ""

# Test 3: Error Handling - Invalid Studio ID
echo "🚨 Testing Error Handling..."
print_status "info" "Testing with invalid studio ID"

timeout 3s curl -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    -X GET \
    "$BASE_URL/api/streaming/process-studio?studio_id=invalid_studio" 2>/dev/null

if [ $? -eq 124 ]; then
    print_status "success" "Error handling test completed (timeout after 3s)"
elif [ $? -eq 0 ]; then
    print_status "success" "Error handling test completed (stream ended)"
else
    print_status "error" "Error handling test failed (exit code: $?)"
fi

echo ""

# Test 4: Error Handling - Missing Studio ID
print_status "info" "Testing with missing studio ID"

timeout 3s curl -N \
    -H "Accept: text/event-stream" \
    -H "Cache-Control: no-cache" \
    -X GET \
    "$BASE_URL/api/streaming/process-studio" 2>/dev/null

if [ $? -eq 124 ]; then
    print_status "success" "Missing studio ID test completed (timeout after 3s)"
elif [ $? -eq 0 ]; then
    print_status "success" "Missing studio ID test completed (stream ended)"
else
    print_status "error" "Missing studio ID test failed (exit code: $?)"
fi

echo ""
echo "🎯 Test Summary:"
echo "================"
print_status "info" "All tests completed with timeout-based validation"
print_status "info" "Check the output above for actual event data"
print_status "info" "For detailed testing, use the Python script: python test_streaming_apis.py"
print_status "info" "For interactive testing, open: test_streaming_web_client.html"

echo ""
print_status "info" "Usage Examples:"
echo "  ./test_streaming_local.sh                                    # Use defaults (localhost:8008)"
echo "  ./test_streaming_local.sh http://localhost:8080              # Custom port"
echo "  ./test_streaming_local.sh http://your-server.com custom_id   # Custom server and studio" 