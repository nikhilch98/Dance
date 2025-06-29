#!/usr/bin/env python3
"""
Quick script to start MCP server and expose it publicly using ngrok
This creates a publicly accessible HTTPS URL that works with OpenAI MCP
"""

import subprocess
import time
import requests
import sys
import signal
import os
from pathlib import Path


def check_ngrok():
    """Check if ngrok is installed"""
    try:
        subprocess.run(["ngrok", "version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def install_ngrok_instructions():
    """Show instructions to install ngrok"""
    print("❌ ngrok is not installed. Please install it:")
    print()
    print("🌐 Option 1: Download from website")
    print("   1. Go to https://ngrok.com/download")
    print("   2. Download for your platform")
    print("   3. Extract and add to PATH")
    print()
    print("🍺 Option 2: Install with Homebrew (macOS)")
    print("   brew install ngrok/ngrok/ngrok")
    print()
    print("📦 Option 3: Install with npm")
    print("   npm install -g @ngrok/ngrok")
    print()
    print("After installation, get your authtoken from:")
    print("https://dashboard.ngrok.com/get-started/your-authtoken")
    print()
    print("Then configure it:")
    print("ngrok config add-authtoken YOUR_AUTHTOKEN")


def start_server():
    """Start the FastAPI server"""
    print("🚀 Starting FastAPI MCP server on port 8002...")
    try:
        # Start server in background
        server_process = subprocess.Popen([
            "uvicorn", "app.main:app", 
            "--reload", 
            "--port", "8002",
            "--host", "0.0.0.0"
        ])
        
        # Wait for server to start
        for i in range(10):
            try:
                response = requests.get("http://localhost:8002/mcp/server-info", timeout=2)
                if response.status_code == 200:
                    print("✅ Server started successfully!")
                    return server_process
            except:
                print(f"⏳ Waiting for server to start... ({i+1}/10)")
                time.sleep(2)
        
        print("❌ Server failed to start")
        server_process.terminate()
        return None
        
    except FileNotFoundError:
        print("❌ uvicorn not found. Please activate your virtual environment:")
        print("source venv/bin/activate")
        return None


def start_ngrok():
    """Start ngrok tunnel"""
    print("🌐 Starting ngrok tunnel...")
    try:
        ngrok_process = subprocess.Popen([
            "ngrok", "http", "8002", "--log=stdout"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # Wait for ngrok to start and get URL
        for i in range(20):
            try:
                # Try to get ngrok API info
                response = requests.get("http://127.0.0.1:4040/api/tunnels", timeout=1)
                if response.status_code == 200:
                    data = response.json()
                    if data.get("tunnels"):
                        tunnel = data["tunnels"][0]
                        public_url = tunnel["public_url"]
                        if public_url.startswith("https://"):
                            print(f"✅ ngrok tunnel started!")
                            print(f"🔗 Public URL: {public_url}")
                            return ngrok_process, public_url
            except:
                pass
            
            print(f"⏳ Waiting for ngrok tunnel... ({i+1}/20)")
            time.sleep(1)
        
        print("❌ ngrok tunnel failed to start")
        ngrok_process.terminate()
        return None, None
        
    except FileNotFoundError:
        print("❌ ngrok not found")
        return None, None


def test_public_endpoint(public_url):
    """Test the public MCP endpoint"""
    print(f"\n🧪 Testing public MCP endpoint...")
    
    try:
        # Test server info
        response = requests.get(f"{public_url}/mcp/server-info", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print("✅ Public server-info endpoint working")
            print(f"   Server: {data.get('server_label')}")
            print(f"   Tools: {data.get('tools_count')}")
        else:
            print(f"❌ Server info failed: {response.status_code}")
            return False
        
        # Test JSON-RPC endpoint
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1
        }
        
        response = requests.post(f"{public_url}/mcp/", json=payload, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get("result") and data["result"].get("tools"):
                print("✅ Public JSON-RPC endpoint working")
                print(f"   Available tools: {len(data['result']['tools'])}")
                return True
            else:
                print("❌ JSON-RPC endpoint returned invalid data")
                return False
        else:
            print(f"❌ JSON-RPC endpoint failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Public endpoint test failed: {e}")
        return False


def update_test_script(public_url):
    """Update the test script with the public URL"""
    test_file = Path("test_random.py")
    if test_file.exists():
        try:
            content = test_file.read_text()
            updated_content = content.replace(
                'server_url = "http://localhost:8002/mcp"',
                f'server_url = "{public_url}/mcp"'
            )
            
            # Create backup
            backup_file = test_file.with_suffix('.py.backup')
            test_file.rename(backup_file)
            
            # Write updated content
            test_file.write_text(updated_content)
            
            print(f"✅ Updated test_random.py with public URL")
            print(f"📄 Backup saved as: {backup_file}")
            return True
            
        except Exception as e:
            print(f"❌ Failed to update test script: {e}")
            return False
    else:
        print("⚠️  test_random.py not found")
        return False


def print_usage_instructions(public_url):
    """Print usage instructions"""
    print("\n" + "=" * 60)
    print("🎉 MCP Server is now publicly accessible!")
    print("=" * 60)
    print(f"📍 Public URL: {public_url}")
    print(f"🔧 MCP Endpoint: {public_url}/mcp/")
    print(f"📊 Server Info: {public_url}/mcp/server-info")
    print()
    print("🚀 OpenAI Integration:")
    print("Now you can use this URL in your OpenAI MCP integration:")
    print()
    print("```python")
    print("resp = client.responses.create(")
    print('    model="gpt-4o",')
    print("    tools=[{")
    print('        "type": "mcp",')
    print('        "server_label": "nachna-workshops",')
    print(f'        "server_url": "{public_url}/mcp",')
    print('        "require_approval": "never",')
    print("    }],")
    print('    input="List of workshops available today"')
    print(")")
    print("```")
    print()
    print("🧪 Test Commands:")
    print("1. Test updated script: python test_random.py")
    print("2. Test server info: curl " + f"{public_url}/mcp/server-info")
    print("3. Test JSON-RPC: curl -X POST " + f"{public_url}/mcp/ -H 'Content-Type: application/json' -d '{{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"id\":1}}'")
    print()
    print("⚠️  Important Notes:")
    print("• This ngrok URL is temporary and will change when restarted")
    print("• For production, deploy to a permanent HTTPS URL")
    print("• Keep this terminal open to maintain the tunnel")
    print()
    print("Press Ctrl+C to stop the server and tunnel")


def cleanup(server_process, ngrok_process):
    """Clean up processes"""
    print("\n🛑 Shutting down...")
    
    if ngrok_process:
        print("Stopping ngrok tunnel...")
        ngrok_process.terminate()
        
    if server_process:
        print("Stopping FastAPI server...")
        server_process.terminate()
    
    print("✅ Cleanup complete")


def main():
    """Main function"""
    print("🚀 Nachna Workshop MCP Server - Public Exposure Tool")
    print("=" * 60)
    print("This tool starts your MCP server and exposes it publicly using ngrok")
    print("so it can be used with OpenAI's MCP integration.")
    print()
    
    # Check if we're in the right directory
    if not Path("app/main.py").exists():
        print("❌ Please run this script from the project root directory")
        sys.exit(1)
    
    # Check ngrok
    if not check_ngrok():
        install_ngrok_instructions()
        sys.exit(1)
    
    server_process = None
    ngrok_process = None
    
    try:
        # Start FastAPI server
        server_process = start_server()
        if not server_process:
            sys.exit(1)
        
        # Start ngrok tunnel
        ngrok_process, public_url = start_ngrok()
        if not ngrok_process or not public_url:
            cleanup(server_process, None)
            sys.exit(1)
        
        # Test public endpoint
        if not test_public_endpoint(public_url):
            cleanup(server_process, ngrok_process)
            sys.exit(1)
        
        # Update test script
        update_test_script(public_url)
        
        # Print instructions
        print_usage_instructions(public_url)
        
        # Wait for interrupt
        signal.signal(signal.SIGINT, lambda sig, frame: cleanup(server_process, ngrok_process) or sys.exit(0))
        
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        cleanup(server_process, ngrok_process)
    except Exception as e:
        print(f"❌ Error: {e}")
        cleanup(server_process, ngrok_process)
        sys.exit(1)


if __name__ == "__main__":
    main() 