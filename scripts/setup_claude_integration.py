#!/usr/bin/env python3
"""
Setup script for Claude Desktop integration with Nachna Workshop MCP server
"""

import json
import os
import platform
import shutil
from pathlib import Path


def get_claude_config_path():
    """Get the Claude Desktop configuration file path based on OS"""
    system = platform.system().lower()
    
    if system == "darwin":  # macOS
        return Path.home() / "Library/Application Support/Claude/claude_desktop_config.json"
    elif system == "windows":
        appdata = os.getenv("APPDATA")
        if appdata:
            return Path(appdata) / "Claude/claude_desktop_config.json"
        else:
            return Path.home() / "AppData/Roaming/Claude/claude_desktop_config.json"
    else:  # Linux and others
        return Path.home() / ".config/claude/claude_desktop_config.json"


def get_server_url():
    """Get the server URL from user input"""
    print("\n🔧 Server Configuration")
    print("=" * 50)
    
    default_url = "http://localhost:8000"
    server_url = input(f"Enter your server URL (default: {default_url}): ").strip()
    
    if not server_url:
        server_url = default_url
    
    # Validate URL format
    if not server_url.startswith(('http://', 'https://')):
        print("⚠️  Warning: URL should start with http:// or https://")
        server_url = f"http://{server_url}"
    
    return server_url


def copy_bridge_script():
    """Copy the MCP bridge script to user's directory"""
    script_dir = Path(__file__).parent.parent
    source_bridge = script_dir / "mcp_bridge.js"
    
    if not source_bridge.exists():
        print(f"❌ Bridge script not found at {source_bridge}")
        return None
    
    # Copy to user's home directory or project directory
    home_dir = Path.home()
    target_bridge = home_dir / "nachna_mcp_bridge.js"
    
    try:
        shutil.copy2(source_bridge, target_bridge)
        # Make it executable
        os.chmod(target_bridge, 0o755)
        print(f"✅ Copied MCP bridge script to {target_bridge}")
        return target_bridge
    except Exception as e:
        print(f"❌ Failed to copy bridge script: {e}")
        return None


def create_claude_config(server_url, bridge_path):
    """Create Claude Desktop configuration"""
    config = {
        "mcpServers": {
            "nachna-workshops": {
                "command": "node",
                "args": [str(bridge_path)],
                "env": {
                    "NACHNA_SERVER_URL": server_url
                }
            }
        }
    }
    
    return config


def backup_existing_config(config_path):
    """Backup existing Claude configuration"""
    if config_path.exists():
        backup_path = config_path.with_suffix('.json.backup')
        try:
            shutil.copy2(config_path, backup_path)
            print(f"✅ Backed up existing config to {backup_path}")
            return True
        except Exception as e:
            print(f"⚠️  Warning: Could not backup existing config: {e}")
            return False
    return True


def merge_configurations(existing_config, new_config):
    """Merge new MCP server with existing configuration"""
    if "mcpServers" not in existing_config:
        existing_config["mcpServers"] = {}
    
    existing_config["mcpServers"]["nachna-workshops"] = new_config["mcpServers"]["nachna-workshops"]
    return existing_config


def save_claude_config(config_path, config):
    """Save Claude Desktop configuration"""
    try:
        # Create directory if it doesn't exist
        config_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing config if it exists
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    existing_config = json.load(f)
                config = merge_configurations(existing_config, config)
                print("✅ Merged with existing Claude configuration")
            except json.JSONDecodeError:
                print("⚠️  Warning: Existing config is invalid JSON, will be replaced")
        
        # Save configuration
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Claude Desktop configuration saved to {config_path}")
        return True
    except Exception as e:
        print(f"❌ Failed to save configuration: {e}")
        return False


def test_server_connection(server_url):
    """Test connection to the MCP server"""
    try:
        import requests
        response = requests.get(f"{server_url}/mcp/server-info", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Server connection successful!")
            print(f"   Server: {data.get('server_label', 'Unknown')}")
            print(f"   Version: {data.get('server_version', 'Unknown')}")
            print(f"   Tools: {data.get('tools_count', 0)}")
            return True
        else:
            print(f"⚠️  Server responded with status {response.status_code}")
            return False
    except ImportError:
        print("⚠️  Cannot test server connection (requests not installed)")
        print("   Please ensure your server is running before using Claude")
        return True  # Don't fail setup for missing requests
    except Exception as e:
        print(f"⚠️  Could not connect to server: {e}")
        print("   Please ensure your server is running before using Claude")
        return True  # Don't fail setup for connection issues


def print_usage_instructions():
    """Print usage instructions for Claude"""
    print("\n🎉 Setup Complete!")
    print("=" * 50)
    print("Your Nachna Workshop MCP server is now configured for Claude Desktop!")
    print()
    print("📋 Next Steps:")
    print("1. Start your Nachna server:")
    print("   uvicorn app.main:app --reload")
    print()
    print("2. Restart Claude Desktop app completely")
    print()
    print("3. Test the integration by asking Claude:")
    print('   "What workshop tools do you have available?"')
    print('   "Show me all current dance workshops"')
    print('   "Find artists who have workshops"')
    print()
    print("💡 Example Claude Queries:")
    print("• Can you get all workshops for this week?")
    print("• Show me information about dance studios")
    print("• Find workshops by a specific artist")
    print("• What artists have workshops scheduled?")
    print()
    print("🔧 Troubleshooting:")
    print("• Ensure your server is running on the configured URL")
    print("• Check Claude Desktop logs if tools don't appear")
    print("• Restart Claude Desktop after any configuration changes")


def main():
    """Main setup function"""
    print("🚀 Nachna Workshop MCP Server - Claude Desktop Setup")
    print("=" * 60)
    print()
    print("This script will configure Claude Desktop to use your Nachna")
    print("Workshop MCP server for accessing dance workshop data.")
    print()
    
    # Get configuration
    server_url = get_server_url()
    
    # Get Claude config path
    config_path = get_claude_config_path()
    print(f"\n📍 Claude config path: {config_path}")
    
    # Copy bridge script
    print("\n📦 Setting up MCP bridge...")
    bridge_path = copy_bridge_script()
    if not bridge_path:
        print("❌ Setup failed: Could not copy bridge script")
        return 1
    
    # Backup existing config
    print("\n💾 Backing up existing configuration...")
    backup_existing_config(config_path)
    
    # Create configuration
    print("\n⚙️  Creating Claude configuration...")
    config = create_claude_config(server_url, bridge_path)
    
    # Save configuration
    if not save_claude_config(config_path, config):
        print("❌ Setup failed: Could not save configuration")
        return 1
    
    # Test server connection
    print("\n🔍 Testing server connection...")
    test_server_connection(server_url)
    
    # Print usage instructions
    print_usage_instructions()
    
    return 0


if __name__ == "__main__":
    exit(main()) 