# MCP Server Integration Guide

## Using Your Nachna Workshop MCP Server with Claude & Other Platforms

This guide explains how to connect your MCP server to Claude Desktop app and other AI platforms that support the Model Context Protocol.

## Quick Start

**Your MCP Server Details:**
- **Server URL**: `http://localhost:8000` (or your deployed URL)
- **Server Label**: `nachna-workshops`
- **Protocol Version**: `1.0`
- **Available Tools**: 4 workshop-related tools
- **Resources**: workshops, artists, studios

## 1. Claude Desktop App Integration

### Prerequisites
- Claude Desktop app (latest version)
- Your MCP server running locally or deployed
- Server accessible via HTTP/HTTPS

### Configuration Steps

#### Step 1: Create MCP Configuration File

Create or edit your Claude Desktop configuration file:

**macOS Location:**
```bash
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Windows Location:**
```bash
%APPDATA%\Claude\claude_desktop_config.json
```

#### Step 2: Add Your MCP Server

Add this configuration to the file:

```json
{
  "mcpServers": {
    "nachna-workshops": {
      "command": "npx",
      "args": [
        "@modelcontextprotocol/server-everything",
        "--url",
        "http://localhost:8000"
      ],
      "env": {
        "MCP_SERVER_URL": "http://localhost:8000",
        "MCP_SERVER_LABEL": "nachna-workshops"
      }
    }
  }
}
```

#### Step 3: Alternative HTTP Configuration

For a simpler HTTP-based setup:

```json
{
  "mcpServers": {
    "nachna-workshops": {
      "command": "curl",
      "args": [
        "-X", "GET",
        "http://localhost:8000/mcp/server-info"
      ]
    }
  }
}
```

#### Step 4: Production Deployment Configuration

For deployed servers (replace with your actual domain):

```json
{
  "mcpServers": {
    "nachna-workshops": {
      "command": "npx",
      "args": [
        "@modelcontextprotocol/server-everything",
        "--url",
        "https://your-domain.com"
      ],
      "env": {
        "MCP_SERVER_URL": "https://your-domain.com",
        "MCP_SERVER_LABEL": "nachna-workshops"
      }
    }
  }
}
```

### Step 5: Restart Claude Desktop

After saving the configuration:
1. Quit Claude Desktop completely
2. Restart the application
3. The MCP server should appear in Claude's tool list

## 2. Testing the Integration

### Verify Connection

Ask Claude to:

1. **List available tools:**
   ```
   What tools do you have available for workshops?
   ```

2. **Get workshop data:**
   ```
   Can you show me all current dance workshops?
   ```

3. **Search for artists:**
   ```
   Find all artists who have workshops scheduled
   ```

4. **Get studio information:**
   ```
   What dance studios are available?
   ```

### Expected Claude Responses

Claude should be able to:
- ✅ Discover your 4 MCP tools automatically
- ✅ Call tools to get workshop data
- ✅ Access artist and studio information
- ✅ Provide formatted responses based on your data

## 3. Other Platform Integration

### 3.1 OpenAI GPTs and Assistants

For OpenAI's platform, you'll need to expose your MCP endpoints as OpenAPI/REST:

```python
# Add to your FastAPI app for OpenAI compatibility
@app.get("/openapi-tools")
async def get_openapi_tools():
    """Convert MCP tools to OpenAPI format for GPTs"""
    mcp_tools = McpWorkshopService.get_available_tools()
    
    openapi_tools = []
    for tool in mcp_tools:
        openapi_tools.append({
            "type": "function",
            "function": {
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.input_schema
            }
        })
    
    return openapi_tools
```

### 3.2 Microsoft Copilot

Create a manifest for Copilot integration:

```json
{
  "schema_version": "v1",
  "name_for_model": "nachna_workshops",
  "name_for_human": "Nachna Dance Workshops",
  "description_for_model": "Access dance workshop, artist, and studio information",
  "description_for_human": "Get information about dance workshops, artists, and studios",
  "auth": {
    "type": "none"
  },
  "api": {
    "type": "openapi",
    "url": "http://localhost:8000/mcp/server-info"
  }
}
```

### 3.3 Custom AI Applications

Use the MCP client libraries:

#### Python Client Example:
```python
import asyncio
import aiohttp
from typing import Dict, Any

class NachnaWorkshopMCPClient:
    def __init__(self, server_url: str = "http://localhost:8000"):
        self.server_url = server_url
        
    async def list_tools(self) -> Dict[str, Any]:
        """Get available MCP tools"""
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{self.server_url}/mcp/tools") as response:
                return await response.json()
    
    async def call_tool(self, tool_name: str, arguments: Dict[str, Any] = None) -> Dict[str, Any]:
        """Call an MCP tool"""
        if arguments is None:
            arguments = {}
            
        payload = {
            "tool_name": tool_name,
            "arguments": arguments
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(f"{self.server_url}/mcp/call", json=payload) as response:
                return await response.json()
    
    async def get_workshops(self, studio_id: str = None) -> Dict[str, Any]:
        """Get workshops using MCP"""
        arguments = {"studio_id": studio_id} if studio_id else {}
        return await self.call_tool("get_workshops_categorized", arguments)

# Usage
async def main():
    client = NachnaWorkshopMCPClient()
    
    # Get all workshops
    workshops = await client.get_workshops()
    print(f"Found {len(workshops['output']['this_week'])} workshops this week")
    
    # Get artists
    artists = await client.call_tool("get_artists", {"has_workshops": True})
    print(f"Found {len(artists['output'])} artists with workshops")

# Run the client
asyncio.run(main())
```

#### JavaScript/Node.js Client Example:
```javascript
class NachnaWorkshopMCPClient {
    constructor(serverUrl = 'http://localhost:8000') {
        this.serverUrl = serverUrl;
    }
    
    async listTools() {
        const response = await fetch(`${this.serverUrl}/mcp/tools`);
        return await response.json();
    }
    
    async callTool(toolName, arguments = {}) {
        const response = await fetch(`${this.serverUrl}/mcp/call`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                tool_name: toolName,
                arguments: arguments
            })
        });
        return await response.json();
    }
    
    async getWorkshops(studioId = null) {
        const arguments = studioId ? { studio_id: studioId } : {};
        return await this.callTool('get_workshops_categorized', arguments);
    }
}

// Usage
const client = new NachnaWorkshopMCPClient();

// Get workshops
client.getWorkshops().then(workshops => {
    console.log(`Found ${workshops.output.this_week.length} workshops this week`);
});
```

## 4. Authentication & Security

### 4.1 Add Authentication to MCP Endpoints

If you need to secure your MCP server:

```python
# Add to app/api/mcp.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def verify_mcp_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify MCP access token"""
    if credentials.credentials != "your-mcp-secret-token":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid MCP access token"
        )
    return credentials.credentials

# Add to your MCP endpoints
@router.get("/tools", response_model=McpListToolsResponse)
async def list_mcp_tools(token: str = Depends(verify_mcp_token)):
    # ... existing code
```

### 4.2 Claude Desktop with Authentication

```json
{
  "mcpServers": {
    "nachna-workshops": {
      "command": "npx",
      "args": [
        "@modelcontextprotocol/server-everything",
        "--url",
        "http://localhost:8000",
        "--header",
        "Authorization: Bearer your-mcp-secret-token"
      ]
    }
  }
}
```

## 5. Production Deployment

### 5.1 Deploy Your MCP Server

Deploy to a cloud platform (Heroku, Railway, DigitalOcean, etc.):

```bash
# Example deployment script
git add .
git commit -m "MCP server ready for deployment"
git push heroku main

# Update Claude config with production URL
# "https://your-app.herokuapp.com"
```

### 5.2 HTTPS Configuration

Ensure HTTPS for production:

```python
# Add to app/main.py for production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://claude.ai", "https://chat.openai.com"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)
```

### 5.3 Rate Limiting for MCP

```python
# Add specific rate limiting for MCP endpoints
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/call")
@limiter.limit("10/minute")  # Limit MCP calls
async def call_mcp_tool(request: Request, ...):
    # ... existing code
```

## 6. Monitoring & Analytics

### 6.1 Track MCP Usage

```python
# Add to app/services/mcp_service.py
import logging
from datetime import datetime

logger = logging.getLogger("mcp_usage")

class McpWorkshopService:
    @classmethod
    def call_tool(cls, tool_name: str, arguments: Dict[str, Any], call_id: str):
        # Log MCP usage
        logger.info(f"MCP tool called: {tool_name} at {datetime.now()}")
        
        # ... existing code
```

### 6.2 Health Checks

```python
# Add health check endpoint
@router.get("/health")
async def mcp_health_check():
    """MCP server health check"""
    try:
        # Test database connection
        DatabaseOperations.get_artists()
        return {
            "status": "healthy",
            "server_label": McpWorkshopService.SERVER_LABEL,
            "timestamp": time.time(),
            "tools_available": len(McpWorkshopService.get_available_tools())
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"MCP server unhealthy: {str(e)}")
```

## 7. Testing & Validation

### 7.1 Test Script

Run the provided test script:

```bash
python scripts/test_mcp_api.py
```

### 7.2 Claude Integration Test

1. Start your server: `uvicorn app.main:app --reload`
2. Configure Claude Desktop with your server
3. Ask Claude: "What workshop tools do you have available?"
4. Verify Claude can access and use your workshop data

## 8. Troubleshooting

### Common Issues:

**Claude can't connect:**
- ✅ Check server is running on correct port
- ✅ Verify configuration file syntax
- ✅ Restart Claude Desktop app
- ✅ Check server logs for errors

**Authentication errors:**
- ✅ Verify token configuration
- ✅ Check CORS settings
- ✅ Ensure HTTPS in production

**Tool calls failing:**
- ✅ Test endpoints manually with curl
- ✅ Check database connectivity
- ✅ Review server logs

### Debug Commands:

```bash
# Test server info
curl http://localhost:8000/mcp/server-info

# Test tool listing
curl http://localhost:8000/mcp/tools

# Test tool call
curl -X POST http://localhost:8000/mcp/call \
  -H "Content-Type: application/json" \
  -d '{"tool_name": "get_workshops_categorized", "arguments": {}}'
```

## 9. Advanced Features

### 9.1 Streaming Responses

For large datasets, implement streaming:

```python
from fastapi.responses import StreamingResponse

@router.get("/stream/workshops")
async def stream_workshops():
    """Stream workshop data for large responses"""
    async def generate():
        workshops = DatabaseOperations.get_all_workshops_categorized()
        yield f"data: {workshops.json()}\n\n"
    
    return StreamingResponse(generate(), media_type="text/plain")
```

### 9.2 Webhook Notifications

Notify Claude of data updates:

```python
@router.post("/webhooks/workshop-updated")
async def workshop_updated_webhook():
    """Notify MCP clients of workshop updates"""
    # Invalidate caches, notify connected clients
    return {"status": "webhook_processed"}
```

## 10. Best Practices

1. **🔒 Security**: Always use HTTPS in production
2. **📊 Monitoring**: Log MCP usage and performance
3. **⚡ Performance**: Implement caching and rate limiting
4. **🛡️ Error Handling**: Provide clear error messages
5. **📱 Responsive**: Design for various client types
6. **🔄 Updates**: Version your MCP tools and maintain backwards compatibility

## Summary

Your Nachna Workshop MCP server is now ready to integrate with Claude and other AI platforms! The server provides a standardized way for AI assistants to access your workshop, artist, and studio data through the Model Context Protocol.

**Next Steps:**
1. Configure Claude Desktop with your server URL
2. Test the integration with sample queries
3. Deploy to production with HTTPS
4. Monitor usage and optimize performance 