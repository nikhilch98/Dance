#!/bin/bash

# Test script for streaming API endpoints
HOST="40.192.39.104:8008"
BASE_URL="http://$HOST/api"

echo "🧪 Testing Streaming API Endpoints"
echo "=================================="
echo "Host: $HOST"
echo ""

# Test 1: Process Studio Streaming
echo "📡 Testing Process Studio Streaming..."
echo "Endpoint: GET $BASE_URL/streaming/process-studio?studio_id=dance_n_addiction"
echo ""

curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "$BASE_URL/streaming/process-studio?studio_id=dance_n_addiction" \
     --max-time 10

echo ""
echo ""

# Test 2: Refresh Workshops Streaming
echo "📡 Testing Refresh Workshops Streaming..."
echo "Endpoint: POST $BASE_URL/streaming/refresh-workshops"
echo ""

curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"studio_id":"dance_n_addiction"}' \
     "$BASE_URL/streaming/refresh-workshops" \
     --max-time 10

echo ""
echo ""
echo "✅ Streaming API tests completed!" 