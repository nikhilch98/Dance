# MCP (Model Context Protocol) API Documentation

## Overview

The Nachna API now supports the **Model Context Protocol (MCP)** for workshop-related operations. MCP provides a standardized way for AI assistants and applications to interact with data sources and tools.

## Key Differences: REST vs MCP

### Regular REST API Endpoints
These remain **unchanged** and work exactly as before:
- `GET /workshops` - Get categorized workshops (REST)
- `GET /artists` - Get artists (REST)  
- `GET /studios` - Get studios (REST)
- `GET /workshops_by_artist/{artist_id}` - Get workshops by artist (REST)
- `GET /workshops_by_studio/{studio_id}` - Get workshops by studio (REST)

### New MCP Protocol Endpoints
These follow the Model Context Protocol standard:
- `GET /mcp/server-info` - Get MCP server capabilities
- `GET /mcp/tools` - List available MCP tools
- `POST /mcp/call` - Execute MCP tool calls
- `GET /mcp/resources/{resource_type}` - Get resources with metadata

**Note:** MCP endpoints are now organized in separate files:
- **Models**: `app/models/mcp.py` - All MCP-specific Pydantic models
- **API Routes**: `app/api/mcp.py` - All MCP endpoints and handlers
- **Service Logic**: `app/services/mcp_service.py` - Business logic for MCP operations

## MCP Server Information

### GET /mcp/server-info

Get information about the MCP server capabilities.

**Response:**
```json
{
  "server_label": "nachna-workshops",
  "server_version": "1.0.0",
  "protocol_version": "1.0",
  "supported_operations": ["list_tools", "call_tool", "get_resource"],
  "available_resources": ["workshops", "artists", "studios"],
  "capabilities": {
    "tools": true,
    "resources": true,
    "prompts": false,
    "logging": false
  },
  "tools_count": 4
}
```

## MCP Tools

### GET /mcp/tools

List all available MCP tools for workshop operations.

**Response:**
```json
{
  "id": "uuid-string",
  "server_label": "nachna-workshops",
  "type": "mcp_list_tools",
  "tools": [
    {
      "name": "get_workshops_categorized",
      "description": "Retrieve all workshops categorized by current week and future periods",
      "input_schema": {
        "type": "object",
        "properties": {
          "studio_id": {
            "type": "string",
            "description": "Optional studio ID to filter workshops by specific studio",
            "required": false
          }
        },
        "additionalProperties": false
      }
    }
    // ... more tools
  ]
}
```

### Available Tools

1. **get_workshops_categorized**
   - Description: Retrieve workshops categorized by current week and future periods
   - Parameters: `studio_id` (optional)

2. **get_workshops_by_artist**
   - Description: Retrieve workshops for a specific artist
   - Parameters: `artist_id` (required)

3. **get_artists**
   - Description: Retrieve all artists with optional filtering
   - Parameters: `has_workshops` (optional boolean)

4. **get_studios**
   - Description: Retrieve all dance studios
   - Parameters: None

## MCP Tool Calls

### POST /mcp/call

Execute an MCP tool call.

**Request Body:**
```json
{
  "tool_name": "get_workshops_categorized",
  "arguments": {
    "studio_id": "optional-studio-id"
  },
  "call_id": "optional-uuid"
}
```

**Response:**
```json
{
  "id": "call-uuid",
  "name": "get_workshops_categorized",
  "server_label": "nachna-workshops", 
  "type": "mcp_call",
  "output": {
    "this_week": [...],
    "post_this_week": [...]
  }
}
```

**Error Response:**
```json
{
  "id": "call-uuid",
  "name": "tool_name",
  "server_label": "nachna-workshops",
  "type": "mcp_call",
  "error": "Error description"
}
```

### Example Tool Calls

#### Get All Workshops
```bash
curl -X POST "http://localhost:8000/mcp/call" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "get_workshops_categorized",
    "arguments": {}
  }'
```

#### Get Workshops by Studio
```bash
curl -X POST "http://localhost:8000/mcp/call" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "get_workshops_categorized",
    "arguments": {
      "studio_id": "studio123"
    }
  }'
```

#### Get Artists with Workshops
```bash
curl -X POST "http://localhost:8000/mcp/call" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "get_artists",
    "arguments": {
      "has_workshops": true
    }
  }'
```

## MCP Resources

### GET /mcp/resources/{resource_type}

Get resources with MCP metadata and caching information.

**Supported Resource Types:**
- `workshops` - All workshop data
- `artists` - All artist data  
- `studios` - All studio data

**Optional Query Parameter:**
- `resource_id` - Filter by specific resource ID (e.g., studio ID for workshops)

**Response:**
```json
{
  "resource_type": "workshops",
  "resource_id": "all",
  "data": {
    "this_week": [...],
    "post_this_week": [...]
  },
  "metadata": {
    "server_label": "nachna-workshops",
    "server_version": "1.0.0",
    "total_this_week": 5,
    "total_future": 12,
    "cache_ttl": 3600,
    "last_updated": 1640995200.0
  },
  "timestamp": 1640995200.0,
  "version": "1.0"
}
```

### Example Resource Calls

#### Get All Workshops Resource
```bash
curl "http://localhost:8000/mcp/resources/workshops"
```

#### Get Artists Resource
```bash
curl "http://localhost:8000/mcp/resources/artists"
```

#### Get Studios Resource  
```bash
curl "http://localhost:8000/mcp/resources/studios"
```

## MCP vs REST Comparison

| Feature | REST API | MCP API |
|---------|----------|---------|
| **Protocol** | HTTP REST | Model Context Protocol |
| **Structure** | Simple request/response | Structured tool calls & resources |
| **Metadata** | Minimal | Rich metadata with caching info |
| **Tool Discovery** | Manual documentation | Programmatic via `/mcp/tools` |
| **Error Handling** | HTTP status codes | Structured error responses |
| **Caching Info** | Headers only | Embedded in response metadata |
| **Backwards Compatibility** | ✅ Unchanged | ✅ New endpoints only |

## Integration Examples

### Python Client
```python
import requests

# Discover available tools
tools_response = requests.get("http://localhost:8000/mcp/tools")
tools = tools_response.json()['tools']

# Call a tool
call_response = requests.post("http://localhost:8000/mcp/call", json={
    "tool_name": "get_workshops_categorized",
    "arguments": {}
})
result = call_response.json()

if result.get('error'):
    print(f"Error: {result['error']}")
else:
    workshops = result['output']
    print(f"Found {len(workshops['this_week'])} workshops this week")
```

### JavaScript/TypeScript Client
```javascript
// Discover tools
const toolsResponse = await fetch('/mcp/tools');
const tools = await toolsResponse.json();

// Call a tool
const callResponse = await fetch('/mcp/call', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    tool_name: 'get_artists',
    arguments: { has_workshops: true }
  })
});

const result = await callResponse.json();
if (result.error) {
  console.error('Error:', result.error);
} else {
  console.log('Artists:', result.output);
}
```

## Benefits of MCP Implementation

1. **Standardization**: Follows the Model Context Protocol standard
2. **Tool Discovery**: Programmatic discovery of available operations
3. **Rich Metadata**: Includes caching, versioning, and server information
4. **Structured Errors**: Consistent error handling across all operations
5. **Future-Proof**: Extensible for additional tools and resources
6. **Backwards Compatible**: REST APIs remain unchanged

## Error Handling

MCP provides structured error handling:

```json
{
  "id": "call-uuid",
  "name": "tool_name", 
  "server_label": "nachna-workshops",
  "type": "mcp_call",
  "error": "Detailed error message"
}
```

Common error scenarios:
- Missing required parameters
- Invalid tool names
- Database connection issues
- Invalid resource types

## Performance & Caching

- MCP responses include cache metadata (`cache_ttl`, `last_updated`)
- Same underlying caching as REST APIs (3600 seconds TTL)
- Rich metadata helps clients implement intelligent caching strategies
- Resource endpoints provide comprehensive caching information

## Testing

Use the provided test script to verify MCP functionality:

```bash
python test_mcp_implementation.py
```

This script tests:
- Server info endpoint
- Tool listing
- Tool calls with various parameters
- Resource retrieval
- Error handling

## Future Enhancements

The MCP implementation is designed to be extensible:

1. **Additional Tools**: Easy to add new workshop-related operations
2. **Prompt Support**: Can be extended to support MCP prompts
3. **Logging**: Framework ready for structured logging
4. **Approval Workflows**: Can implement approval mechanisms for sensitive operations
5. **Streaming**: Potential for streaming responses for large datasets

## File Organization

The MCP implementation is cleanly separated into dedicated files:

```
app/
├── models/
│   ├── mcp.py              # MCP-specific Pydantic models
│   └── workshops.py        # Workshop models (MCP-free)
├── api/
│   ├── mcp.py              # MCP protocol endpoints
│   └── workshops.py        # Regular REST endpoints (unchanged)
├── services/
│   └── mcp_service.py      # MCP business logic and tool implementations
└── main.py                 # App factory (includes MCP router at /mcp prefix)
```

### Benefits of Separation:
- **Clean Concerns**: MCP code doesn't pollute workshop-specific files
- **Easy Maintenance**: MCP features can be updated independently
- **Better Testing**: MCP functionality can be tested in isolation
- **Modular Design**: MCP can be easily extended or removed
- **Clear Boundaries**: Workshop REST APIs remain completely unchanged

## Migration Guide

**No migration required!** 

- Existing REST API clients continue to work unchanged
- New MCP clients can use the `/mcp/*` endpoints
- Both APIs access the same underlying data
- Same authentication and rate limiting applies
- MCP code is completely separated from existing workshop code 