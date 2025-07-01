#!/bin/bash

echo "=== Nachna Server Health Check Test ==="
echo ""

# Test basic health check
echo "1. Testing basic health check..."
response=$(curl -s http://localhost:8008/api/health_check)
if [[ $? -eq 0 ]]; then
    echo "✅ Health check endpoint is reachable"
    echo "Response: $response"
else
    echo "❌ Health check endpoint failed"
    exit 1
fi

echo ""

# Test JSON structure
echo "2. Testing JSON structure..."
success=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('success', False))" 2>/dev/null)
status=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('status', ''))" 2>/dev/null)
service=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('service', ''))" 2>/dev/null)

if [[ "$success" == "True" ]] && [[ "$status" == "healthy" ]] && [[ "$service" == "nachna-server" ]]; then
    echo "✅ JSON structure is correct"
    echo "   - success: $success"
    echo "   - status: $status"
    echo "   - service: $service"
else
    echo "❌ JSON structure is incorrect"
    exit 1
fi

echo ""

# Test response time
echo "3. Testing response time..."
start_time=$(date +%s%N)
curl -s http://localhost:8008/api/health_check > /dev/null
end_time=$(date +%s%N)
response_time_ms=$(( (end_time - start_time) / 1000000 ))

if [[ $response_time_ms -lt 1000 ]]; then
    echo "✅ Response time is good: ${response_time_ms}ms"
else
    echo "⚠️  Response time is slow: ${response_time_ms}ms"
fi

echo ""

# Test CORS
echo "4. Testing CORS support..."
cors_response=$(curl -s -X OPTIONS -I http://localhost:8008/api/health_check 2>/dev/null | head -1)
if [[ "$cors_response" == *"200 OK"* ]]; then
    echo "✅ CORS OPTIONS request succeeds"
else
    echo "❌ CORS OPTIONS request failed"
fi

echo ""

# Test invalid endpoints
echo "5. Testing invalid endpoint..."
invalid_response=$(curl -s -w "%{http_code}" http://localhost:8008/api/invalid_endpoint -o /dev/null)
if [[ "$invalid_response" == "404" ]]; then
    echo "✅ Invalid endpoints return 404 as expected"
else
    echo "⚠️  Invalid endpoint returned: $invalid_response"
fi

echo ""
echo "=== Health Check Test Complete ==="