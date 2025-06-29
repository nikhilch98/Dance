from openai import OpenAI
import requests
from app.models.workshops import Artist
# First, let's test if our MCP server is running locally
def test_local_server():
    try:
        response = requests.get("https://nachna.com/mcp/server-info")
        if response.status_code == 200:
            print("✅ Local MCP server is running")
            print(f"Server info: {response.json()}")
            return True
        else:
            print(f"❌ Local server responded with {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Cannot connect to local server: {e}")
        return False

# Test the JSON-RPC endpoint
def test_jsonrpc_endpoint():
    try:
        # Test tools/list method
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1
        }
        
        response = requests.post("https://nachna.com/mcp/", json=payload)
        if response.status_code == 200:
            data = response.json()
            print("✅ JSON-RPC endpoint working")
            print(f"Available tools: {len(data['result']['tools'])}")
            for tool in data['result']['tools']:
                print(f"  - {tool['name']}: {tool['description']}")
            return True
        else:
            print(f"❌ JSON-RPC endpoint failed: {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ JSON-RPC test failed: {e}")
        return False

# Test the server first
print("🔍 Testing local MCP server...")
if test_local_server() and test_jsonrpc_endpoint():
    print("\n🚀 Trying OpenAI MCP integration...")
    
    client = OpenAI()

    # Use the correct server URL - replace with your actual deployment URL
    # For local testing, you might need to expose your server publicly
    server_url = "https://nachna.com/mcp"  # Change this to your deployed URL
    
    try:
        resp = client.responses.create(
            model="gpt-4o",  # Fixed model name
            tools=[
                {
                    "type": "mcp",
                    "server_label": "nachna-workshops",
                    "server_url": server_url,
                    "require_approval": "never",
                },
            ],
            input="Get all workshops that are happening today",
        )

        print("✅ OpenAI MCP integration successful!")
        print(resp.output_text)
        
    except Exception as e:
        print(f"❌ OpenAI MCP integration failed: {e}")
        print("\n💡 Possible solutions:")
        print("1. Deploy your server to a public URL (not localhost)")
        print("2. Update server_url to your deployed URL")
        print("3. Ensure the deployed server has CORS enabled for OpenAI")
        
else:
    print("\n❌ Local server not working. Please start your server first:")
    print("source venv/bin/activate")
    print("uvicorn app.main:app --reload --port 8002")
    print("")
    print("💡 Or use the automated public server script:")
    print("python scripts/start_public_mcp_server.py")