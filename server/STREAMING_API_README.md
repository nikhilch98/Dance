# Workshop Streaming API

This document describes the streaming API implementation for real-time workshop processing updates.

## Overview

The streaming API provides real-time updates during workshop refresh and studio processing operations using Server-Sent Events (SSE). It sends two types of updates:

1. **Logs** - Text-based log messages with different levels (info, warning, error, success)
2. **Progress Bar** - Numeric progress updates with percentage, current count, and total count

## API Endpoints

### 1. Refresh Workshops Streaming
**Endpoint:** `POST /api/streaming/refresh-workshops`

**Request Body:**
```json
{
  "studio_id": "dance_n_addiction"
}
```

**Response:** Server-Sent Events stream

### 2. Process Studio Streaming
**Endpoint:** `GET /api/streaming/process-studio?studio_id={studio_id}`

**Query Parameters:**
- `studio_id` (required): The ID of the studio to process

**Response:** Server-Sent Events stream

## Response Format

### Log Event
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

### Progress Bar Event
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

## Event Types

### Log Levels
- `info` - General information messages
- `success` - Successful operations
- `warning` - Warning messages
- `error` - Error messages

### Special Events
- `error` - Connection or processing errors
- `complete` - Process completion
- `close` - Connection closure

## Client Implementation

### JavaScript Example
```javascript
const eventSource = new EventSource('/api/streaming/refresh-workshops');

eventSource.addEventListener('logs', function(event) {
    const data = JSON.parse(event.data);
    console.log(`[${data.data.level}] ${data.data.message}`);
});

eventSource.addEventListener('progress_bar', function(event) {
    const data = JSON.parse(event.data);
    console.log(`Progress: ${data.data.percentage}% (${data.data.current}/${data.data.total})`);
});

eventSource.addEventListener('complete', function(event) {
    console.log('Process completed');
    eventSource.close();
});

eventSource.onerror = function(event) {
    console.error('Connection error:', event);
};
```

### cURL Example
```bash
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X POST \
     -d '{"studio_id":"dance_n_addiction"}' \
     http://localhost:8008/api/streaming/refresh-workshops
```

## Architecture

### Components

1. **Streaming Response Models** (`models/response/streaming.go`)
   - Defines response structures for logs and progress updates
   - Provides helper functions for creating responses

2. **Streaming Workshop Service** (`service/streamingWorkshop.go`)
   - Handles the business logic for streaming operations
   - Sends updates through channels
   - Integrates with existing admin services

3. **Streaming API Handlers** (`api/streamingWorkshop.go`)
   - Implements Server-Sent Events endpoints
   - Manages connection lifecycle
   - Handles request parsing and response streaming

### Flow

1. Client sends request to streaming endpoint
2. API handler creates update channel and starts processing goroutine
3. Service processes workshops/studio and sends updates through channel
4. API handler streams updates to client as Server-Sent Events
5. Connection closes when processing completes or client disconnects

## Configuration

### Timeouts
- Connection timeout: 30 minutes
- Processing timeout: Configurable in service

### Buffer Size
- Update channel buffer: 100 messages
- Prevents blocking when client is slow

## Error Handling

### Client Disconnection
- Detected via `r.Context().Done()`
- Gracefully closes connection and cleanup

### Processing Errors
- Sent as error events to client
- Logged with error level
- Connection remains open for other updates

### Timeout Handling
- Context timeout after 30 minutes
- Sends close event to client
- Cleans up resources

## Testing

### Test Client
A test HTML client is provided at `test_streaming_client.html` that demonstrates:
- Real-time progress updates
- Log message display
- Connection status management
- Error handling

### Usage
1. Start the server
2. Open `test_streaming_client.html` in a browser
3. Click "Refresh Workshops" or "Process Studio" buttons
4. Watch real-time updates

## Integration with Existing Code

The streaming API integrates with existing services:

- Uses existing `AdminService` and `AdminStudioService`
- Leverages existing request/response models
- Maintains compatibility with non-streaming endpoints
- Follows existing error handling patterns

## Performance Considerations

- Uses goroutines for non-blocking processing
- Buffered channels prevent memory issues
- Connection pooling for multiple clients
- Graceful cleanup on disconnection

## Security

- CORS headers configured for cross-origin requests
- Input validation on request parameters
- No sensitive data in streaming responses
- Rate limiting can be added if needed

## Future Enhancements

1. **Authentication**: Add authentication to streaming endpoints
2. **Rate Limiting**: Implement rate limiting for streaming connections
3. **Metrics**: Add metrics collection for streaming usage
4. **WebSocket Support**: Add WebSocket alternative to SSE
5. **Compression**: Add gzip compression for large update streams 