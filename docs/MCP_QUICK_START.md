# 🚀 Quick Start: Using Your MCP Server with Claude

Your Nachna Workshop API now supports the **Model Context Protocol (MCP)** for seamless integration with Claude and other AI platforms!

## ⚡ Quick Setup for Claude Desktop

### Option 1: Automated Setup (Recommended)

```bash
# 1. Start your server
uvicorn app.main:app --reload

# 2. Run the setup script
python scripts/setup_claude_integration.py

# 3. Restart Claude Desktop
# 4. Ask Claude: "What workshop tools do you have available?"
```

### Option 2: Manual Setup

1. **Copy the configuration file:**
   ```bash
   # macOS
   cp claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
   
   # Windows
   cp claude_desktop_config.json %APPDATA%\Claude\claude_desktop_config.json
   ```

2. **Copy the bridge script:**
   ```bash
   cp mcp_bridge.js ~/nachna_mcp_bridge.js
   ```

3. **Update the configuration file** to use the correct path to the bridge script

4. **Start your server** and **restart Claude Desktop**

## 🎯 Test Your Integration

Once configured, ask Claude these questions:

### 📋 Discovery
- "What tools do you have available for workshops?"
- "Can you list your capabilities?"

### 📅 Workshop Data
- "Show me all current dance workshops"
- "What workshops are happening this week?"
- "Find workshops for next week"

### 👥 Artists & Studios
- "Show me all dance artists"
- "Which artists have workshops scheduled?"
- "List all dance studios"
- "Find workshops by [Artist Name]"

### 🏢 Studio-Specific
- "Get workshops for [Studio Name]"
- "Show me workshops at specific studios"

## 🔧 Your MCP Server Details

- **Server Label**: `nachna-workshops`
- **Available Tools**: 4 workshop-related tools
- **Resources**: workshops, artists, studios
- **Protocol Version**: 1.0

### Available Tools:
1. **get_workshops_categorized** - Get all workshops (optional: filter by studio)
2. **get_workshops_by_artist** - Get workshops for specific artist
3. **get_artists** - Get all artists (optional: filter by who has workshops)
4. **get_studios** - Get all dance studios

## 🌐 Other Platforms

### For OpenAI GPTs
Use the OpenAPI-compatible endpoint:
```
GET /openapi-tools
```

### For Custom Applications
```python
import requests

# Get available tools
tools = requests.get("http://localhost:8000/mcp/tools").json()

# Call a tool
response = requests.post("http://localhost:8000/mcp/call", json={
    "tool_name": "get_workshops_categorized",
    "arguments": {}
})
```

## 📚 Complete Documentation

- **[MCP Integration Guide](MCP_INTEGRATION_GUIDE.md)** - Complete setup for all platforms
- **[MCP API Documentation](MCP_API_DOCUMENTATION.md)** - Full API reference
- **[Test Script](scripts/test_mcp_api.py)** - Test your MCP server

## 🔍 Troubleshooting

**Claude can't find tools?**
- ✅ Check server is running: `curl http://localhost:8000/mcp/server-info`
- ✅ Restart Claude Desktop completely
- ✅ Verify configuration file location

**Tool calls failing?**
- ✅ Test manually: `python scripts/test_mcp_api.py`
- ✅ Check server logs
- ✅ Verify database connection

**Need help?**
- Test with: `curl http://localhost:8000/mcp/tools`
- Check logs: Server console output
- Verify bridge: `node mcp_bridge.js` (should start without errors)

## 🎉 What Claude Can Do Now

✅ **Discover** your workshop tools automatically  
✅ **Access** real-time workshop data  
✅ **Filter** workshops by studios and artists  
✅ **Search** for specific workshops  
✅ **Get** comprehensive artist and studio information  
✅ **Provide** formatted responses with your data  

Your workshop data is now AI-accessible! 🎊 