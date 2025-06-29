"""Test script for MCP (Model Context Protocol) implementation."""

import requests
import json
from typing import Dict, Any

# Base URL for the API (adjust as needed)
BASE_URL = "http://localhost:8000"

def test_mcp_server_info():
    """Test the MCP server info endpoint."""
    print("🔍 Testing MCP Server Info...")
    response = requests.get(f"{BASE_URL}/mcp/server-info")
    
    if response.status_code == 200:
        data = response.json()
        print("✅ MCP Server Info:")
        print(json.dumps(data, indent=2))
        return True
    else:
        print(f"❌ Failed to get server info: {response.status_code}")
        return False

def test_mcp_list_tools():
    """Test the MCP tools listing endpoint."""
    print("\n🔍 Testing MCP Tools Listing...")
    response = requests.get(f"{BASE_URL}/mcp/tools")
    
    if response.status_code == 200:
        data = response.json()
        print("✅ Available MCP Tools:")
        print(f"Server Label: {data['server_label']}")
        print(f"Tools Count: {len(data['tools'])}")
        
        for tool in data['tools']:
            print(f"\n📋 Tool: {tool['name']}")
            print(f"   Description: {tool['description']}")
            print(f"   Input Schema: {json.dumps(tool['input_schema'], indent=6)}")
        return True
    else:
        print(f"❌ Failed to list tools: {response.status_code}")
        return False

def test_mcp_call_tool(tool_name: str, arguments: Dict[str, Any] = None):
    """Test calling an MCP tool."""
    if arguments is None:
        arguments = {}
    
    print(f"\n🔍 Testing MCP Tool Call: {tool_name}")
    
    payload = {
        "tool_name": tool_name,
        "arguments": arguments
    }
    
    response = requests.post(f"{BASE_URL}/mcp/call", json=payload)
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Tool Call Successful:")
        print(f"   Tool: {data['name']}")
        print(f"   Server: {data['server_label']}")
        print(f"   Type: {data['type']}")
        
        if data.get('error'):
            print(f"   Error: {data['error']}")
        elif data.get('output'):
            # Truncate output for readability
            output = data['output']
            if isinstance(output, dict):
                print(f"   Output Keys: {list(output.keys())}")
            elif isinstance(output, list):
                print(f"   Output Count: {len(output)}")
            else:
                print(f"   Output: {str(output)[:200]}...")
        
        return True
    else:
        print(f"❌ Tool call failed: {response.status_code}")
        print(f"   Response: {response.text}")
        return False

def test_mcp_get_resource(resource_type: str, resource_id: str = None):
    """Test getting an MCP resource."""
    print(f"\n🔍 Testing MCP Resource: {resource_type}" + (f"/{resource_id}" if resource_id else ""))
    
    url = f"{BASE_URL}/mcp/resources/{resource_type}"
    if resource_id:
        url += f"?resource_id={resource_id}"
    
    response = requests.get(url)
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Resource Retrieved:")
        print(f"   Type: {data['resource_type']}")
        print(f"   ID: {data['resource_id']}")
        print(f"   Timestamp: {data['timestamp']}")
        print(f"   Metadata: {json.dumps(data['metadata'], indent=6)}")
        
        # Truncate data for readability
        resource_data = data['data']
        if isinstance(resource_data, dict):
            print(f"   Data Keys: {list(resource_data.keys())}")
        elif isinstance(resource_data, list):
            print(f"   Data Count: {len(resource_data)}")
        else:
            print(f"   Data: {str(resource_data)[:200]}...")
        
        return True
    else:
        print(f"❌ Resource retrieval failed: {response.status_code}")
        print(f"   Response: {response.text}")
        return False

def main():
    """Run all MCP tests."""
    print("🚀 Starting MCP Implementation Tests")
    print("=" * 50)
    
    # Test server info
    if not test_mcp_server_info():
        print("❌ Server info test failed. Exiting.")
        return
    
    # Test tools listing
    if not test_mcp_list_tools():
        print("❌ Tools listing test failed. Exiting.")
        return
    
    # Test various tool calls
    test_mcp_call_tool("get_workshops_categorized")
    test_mcp_call_tool("get_artists")
    test_mcp_call_tool("get_studios")
    test_mcp_call_tool("get_artists", {"has_workshops": True})
    
    # Test resources
    test_mcp_get_resource("workshops")
    test_mcp_get_resource("artists")
    test_mcp_get_resource("studios")
    
    print("\n" + "=" * 50)
    print("🎉 MCP Implementation Tests Completed!")

if __name__ == "__main__":
    main() 